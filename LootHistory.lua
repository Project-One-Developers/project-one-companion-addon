local _, POI = ... -- Internal namespace

local GetItemInfo = C_Item and C_Item.GetItemInfo or GetItemInfo
local GetItemInfoInstant = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant

-- Class lookup tables (replacing ExRT.GDB)
local CLASS_STRING_TO_ID = {
    WARRIOR = 1, PALADIN = 2, HUNTER = 3, ROGUE = 4, PRIEST = 5,
    DEATHKNIGHT = 6, SHAMAN = 7, MAGE = 8, WARLOCK = 9, MONK = 10,
    DRUID = 11, DEMONHUNTER = 12, EVOKER = 13,
}
local CLASS_ID_TO_STRING = {
    "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST",
    "DEATHKNIGHT", "SHAMAN", "MAGE", "WARLOCK", "MONK",
    "DRUID", "DEMONHUNTER", "EVOKER",
}

-- Allowed raid difficulties
local ALLOWED_DIFFICULTIES = {
    [14] = true, -- raid normal
    [15] = true, -- raid hc
    [16] = true, -- raid mythic
    [23] = true, -- mythic+
    [8]  = true, -- other
}

-- Roll state mapping (modern retail API)
local ROLL_STATE_TO_TYPE = {
    [0] = 1, -- NeedMainSpec -> need
    [1] = 1, -- NeedOffSpec -> need
    [2] = 3, -- Transmog
    [3] = 2, -- Greed
    [4] = 0, -- NoRoll -> pass
    [5] = 0, -- Pass
}

local ROLL_TYPE_ICONS = {
    ["0"] = "|A:lootroll-icon-pass:20:20|a",
    ["1"] = "|A:lootroll-rollicon-yourolled-need:20:20|a",
    ["2"] = "|A:lootroll-rollicon-yourolled-greed:20:20|a",
    ["3"] = "|A:lootroll-rollicon-yourolled-transmog:20:20|a",
}

-- Module namespace
POI.LootHistory = {}
local LH = POI.LootHistory

LH.CLASS_ID_TO_STRING = CLASS_ID_TO_STRING
LH.ROLL_TYPE_ICONS = ROLL_TYPE_ICONS

-- Deduplication table for roll tracking (session-local)
local rollIDtoRecord = {}
local prevEncounterID = nil

function LH:ClassColor(classToken)
    local color = RAID_CLASS_COLORS[classToken]
    if color and color.colorStr then
        return color.colorStr
    end
    return "ffbbbbbb"
end

function LH:ParseRecord(record)
    local timeRec, encounterID, instanceID, difficulty, playerName, classID, quantity, itemLink, rollType = strsplit("#", record)
    return {
        time = tonumber(timeRec),
        encounterID = tonumber(encounterID),
        instanceID = tonumber(instanceID),
        difficulty = tonumber(difficulty),
        playerName = playerName,
        classID = tonumber(classID),
        quantity = tonumber(quantity),
        itemLink = itemLink,
        rollType = rollType,
    }
end

function LH:SetEnabled(enabled)
    POC.LootHistory.enabled = enabled
end

function LH:IsEnabled()
    return POC.LootHistory and POC.LootHistory.enabled
end

-- Auto-migration from MRT data
function LH:MigrateFromMRT()
    if not VMRT or not VMRT.LootHistory or not VMRT.LootHistory.list then return false end
    if #POC.LootHistory.list > 0 then return false end -- don't overwrite existing data

    for i, record in ipairs(VMRT.LootHistory.list) do
        POC.LootHistory.list[i] = record
    end
    for k, v in pairs(VMRT.LootHistory.bossNames or {}) do
        POC.LootHistory.bossNames[k] = v
    end
    for k, v in pairs(VMRT.LootHistory.instanceNames or {}) do
        POC.LootHistory.instanceNames[k] = v
    end

    local count = #POC.LootHistory.list
    if count > 0 then
        print("|cFF00FFFFPOC|r Migrated " .. count .. " loot records from Method Raid Tools.")
    end
    return true, count
end

-- Event dispatcher
function LH:HandleEvent(event, ...)
    if not self:IsEnabled() then return end

    if event == "BOSS_KILL" then
        self:OnBossKill(...)
    elseif event == "ENCOUNTER_LOOT_RECEIVED" then
        self:OnEncounterLootReceived(...)
    elseif event == "LOOT_HISTORY_UPDATE_ENCOUNTER" then
        self:OnLootHistoryUpdateEncounter(...)
    elseif event == "LOOT_HISTORY_UPDATE_DROP" then
        local encounterID = ...
        self:OnLootHistoryUpdateEncounter(encounterID)
    elseif event == "ENCOUNTER_END" then
        local encounterID = ...
        prevEncounterID = encounterID
    end
end

function LH:OnBossKill(encounterID, name)
    if encounterID == 0 or not encounterID then return end
    POC.LootHistory.bossNames[encounterID] = name
end

function LH:OnEncounterLootReceived(encounterID, itemID, itemLink, quantity, playerName, className)
    local instanceName, _, difficulty, _, _, _, _, instanceID = GetInstanceInfo()

    if not difficulty or not ALLOWED_DIFFICULTIES[difficulty] then
        -- MRT has this commented out (allows all difficulties to pass through)
    end

    POC.LootHistory.instanceNames[instanceID or 0] = instanceName

    local currTime = time()
    local classID = CLASS_STRING_TO_ID[className] or 0

    local itemLinkShort = itemLink:match("(item:.-)|h")
    if not itemLinkShort then return end

    local _, _, itemRarity = GetItemInfo(itemLinkShort)
    if itemRarity and itemRarity < 4 then return end

    local record = currTime .. "#" .. (encounterID or 0) .. "#" .. (instanceID or 0) .. "#" .. (difficulty or 0) .. "#" .. playerName .. "#" .. classID .. "#" .. quantity .. "#" .. itemLinkShort
    POC.LootHistory.list[#POC.LootHistory.list + 1] = record
end

local function FindInValue(t, val)
    for k, v in pairs(t) do
        if v == val then return k end
    end
end

function LH:OnLootHistoryUpdateEncounter(encounterID)
    local instanceName, instance_type, difficulty, _, _, _, _, instanceID = GetInstanceInfo()
    local drops = C_LootHistory.GetSortedDropsForEncounter(encounterID)
    if not drops then return end

    for _, dropInfo in ipairs(drops) do
        local lootListID = dropInfo.lootListID
        local itemLink = dropInfo and dropInfo.itemHyperlink
        if itemLink then
            local rollID = (encounterID or "") .. "-" .. (difficulty or 0) .. "-" .. (lootListID or "0")

            local currTime, playerName, classID, quantity, itemLinkShort, rollType, _
            local recordID

            if not rollIDtoRecord[rollID] then
                for i = #POC.LootHistory.list, 1, -1 do
                    local t, eID, iID, dID, _, _, _, il = strsplit("#", POC.LootHistory.list[i])
                    if eID and iID and dID and tostring(instanceID) == iID and encounterID and tostring(encounterID) == eID and dID == tostring(difficulty or "") and t and tonumber(t) and time() - tonumber(t) <= 420 then
                        if type(il) == "string" and il:match("item:%d+") == itemLink:match("item:%d+") and not FindInValue(rollIDtoRecord, i) then
                            rollIDtoRecord[rollID] = i
                            break
                        end
                    else
                        break
                    end
                end
            end

            if rollIDtoRecord[rollID] then
                recordID = rollIDtoRecord[rollID]
                currTime, _, _, _, playerName, classID, quantity, itemLinkShort, rollType = strsplit("#", POC.LootHistory.list[recordID])
                if type(itemLinkShort) ~= "string" or itemLinkShort:match("item:%d+") ~= itemLink:match("item:%d+") then
                    currTime, playerName, classID, quantity, itemLinkShort = nil
                    recordID = nil
                end
            end

            if dropInfo.winner then
                playerName = dropInfo.winner.playerName
                classID = CLASS_STRING_TO_ID[dropInfo.winner.playerClass or ""] or 0
                if dropInfo.playerRollState then
                    rollType = ROLL_STATE_TO_TYPE[dropInfo.playerRollState]
                end
            end

            if not currTime then
                currTime = time()
                itemLinkShort = itemLink:match("(item:.-)|h")

                local _, _, itemRarity = GetItemInfo(itemLink)
                if itemRarity and itemRarity < 4 then
                    currTime = nil
                end
            end

            if currTime then
                local record = currTime .. "#" .. (encounterID or 0) .. "#" .. (instanceID or 0) .. "#" .. (difficulty or 0) .. "#" .. (playerName or "") .. "#" .. (classID or "0") .. "#" .. (quantity or "1") .. "#" .. itemLinkShort .. (rollType and "#" .. rollType or "")

                POC.LootHistory.instanceNames[instanceID or 0] = instanceName

                recordID = recordID or #POC.LootHistory.list + 1
                POC.LootHistory.list[recordID] = record
                rollIDtoRecord[rollID] = recordID
            end
        end
    end
end
