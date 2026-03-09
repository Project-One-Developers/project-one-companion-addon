local _, POI = ... -- Internal namespace
local DF = _G["DetailsFramework"]

local GetItemInfo = C_Item and C_Item.GetItemInfo or GetItemInfo
local GetItemInfoInstant = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant

local window_width = 900
local window_height = 515
local expressway = [[Interface\AddOns\P1Companion\Media\Fonts\Expressway.TTF]]

local options_dropdown_template = DF:GetTemplate("dropdown", "OPTIONS_DROPDOWN_TEMPLATE")
local options_button_template = DF:GetTemplate("button", "OPTIONS_BUTTON_TEMPLATE")
local options_switch_template = DF:GetTemplate("switch", "OPTIONS_CHECKBOX_TEMPLATE")

POI.LootHistoryUI = {}
local LHUI = POI.LootHistoryUI
local LH = POI.LootHistory

-- Session-local flag for delete confirmation
local enableDel = false

function LHUI:BuildLootTab(parent)
    local tabWidth = window_width - 40
    local tabHeight = window_height - 180

    -- Search box
    local searchLabel = DF:CreateLabel(parent, "Search", 9.5, "white")
    searchLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -90)

    local searchEntry = DF:CreateTextEntry(parent, function() end, 250, 18, nil, nil, nil, options_dropdown_template)
    searchEntry.tooltip = "Comma-separated filters: player, boss, instance, item, difficulty, pass/need/greed"
    searchEntry:SetPoint("LEFT", searchLabel, "RIGHT", 5, 0)

    local searchTimer = nil
    local currentSearch = nil

    searchEntry:SetHook("OnTextChanged", function(self, isUser)
        if not isUser then return end
        local text = self:GetText():lower()
        if text == "" then
            currentSearch = nil
        else
            local terms = { strsplit(",", text) }
            currentSearch = {}
            for i = #terms, 1, -1 do
                if terms[i] ~= "" then
                    currentSearch[#currentSearch + 1] = terms[i]
                end
            end
            if #currentSearch == 0 then currentSearch = nil end
        end
        if searchTimer then return end
        searchTimer = C_Timer.NewTimer(0.3, function()
            searchTimer = nil
            LHUI:RefreshData()
        end)
    end)

    -- Export button
    local exportButton = DF:CreateButton(parent, function()
        POI:ExportLootsPopup(150)
    end, 80, 18, "Export")
    exportButton:SetTemplate(options_button_template)
    exportButton:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -30, -90)

    -- Clear button
    local clearButton = DF:CreateButton(parent, function()
        StaticPopupDialogs["P1C_LOOTHISTORY_CLEAR"] = {
            text = "Clear ALL loot history data?",
            button1 = "Yes",
            button2 = "No",
            OnAccept = function()
                table.wipe(POC.LootHistory.list)
                table.wipe(POC.LootHistory.bossNames)
                table.wipe(POC.LootHistory.instanceNames)
                LHUI:RefreshData()
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
        StaticPopup_Show("P1C_LOOTHISTORY_CLEAR")
    end, 80, 18, "Clear All")
    clearButton:SetTemplate(options_button_template)
    clearButton:SetPoint("RIGHT", exportButton, "LEFT", -10, 0)

    -- Enable/disable checkbox
    local enableCheck = DF:CreateSwitch(parent, function(self, fixedParam, value)
        LH:SetEnabled(value)
    end, POC.LootHistory.enabled, 18, 18)
    enableCheck:SetAsCheckBox()
    enableCheck:SetPoint("RIGHT", clearButton, "LEFT", -15, 0)

    local enableLabel = DF:CreateLabel(parent, "Track Loot", 9.5, "white")
    enableLabel:SetPoint("RIGHT", enableCheck, "LEFT", -5, 0)

    -- Header
    local headerTable = {
        { text = "Date",       width = 120 },
        { text = "Instance",   width = 120 },
        { text = "Boss",       width = 140 },
        { text = "Difficulty", width = 80 },
        { text = "Player",     width = 110 },
        { text = "Bind",       width = 50 },
        { text = "Item",       width = 170 },
    }

    local resultsFrame = CreateFrame("frame", parent:GetName() .. "LootResultsFrame", parent)
    resultsFrame:SetPoint("topleft", parent, "topleft", 10, -140)
    resultsFrame:SetSize(tabWidth, tabHeight)

    resultsFrame.Header = DF:CreateHeader(resultsFrame, headerTable, { padding = 2 })
    resultsFrame.Header:SetPoint("topleft", resultsFrame, "topleft", 0, 20)

    -- Scroll refresh function
    local bindCache = {}
    local function GetBindLabel(itemLink)
        local cached = bindCache[itemLink]
        if cached ~= nil then return cached end

        local tooltipData = C_TooltipInfo.GetHyperlink(itemLink)
        if not tooltipData then return "" end
        for _, line in ipairs(tooltipData.lines) do
            local text = line.leftText
            if text then
                if text == ITEM_BIND_ON_EQUIP then bindCache[itemLink] = "BoE"; return "BoE" end
                if text:find("Warband") then bindCache[itemLink] = "WUE"; return "WUE" end
                if text == ITEM_ACCOUNTBOUND or text == ITEM_BNETACCOUNTBOUND then bindCache[itemLink] = "BoA"; return "BoA" end
            end
        end
        bindCache[itemLink] = ""
        return ""
    end
    local function refresh(self, data, offset, totalLines)
        local needsRetry = false
        for i = 1, totalLines do
            local index = i + offset
            local thisData = data[index]
            if thisData then
                local line = self:GetLine(i)
                line.data = thisData

                line.Date:SetText(thisData.dateStr or "")
                line.Instance:SetText(thisData.instanceName or "")
                line.Boss:SetText(thisData.bossName or "")
                line.Difficulty:SetText(thisData.diffName or "")
                line.Player:SetText(thisData.playerStr or "")

                -- Item info (may need async loading)
                if thisData.itemLink then
                    local itemName, itemLinkQ, itemRarity, _, _, _, _, _, _, itemIcon = GetItemInfo(thisData.itemLink)
                    if not itemIcon then
                        itemIcon = select(5, GetItemInfoInstant(thisData.itemLink))
                    end

                    if itemLinkQ then
                        itemLinkQ = itemLinkQ:gsub("[%[%]]", "")
                        local qtyStr = (thisData.quantity and thisData.quantity > 1) and (thisData.quantity .. "x") or ""
                        local iconStr = itemIcon and ("|T" .. itemIcon .. ":16|t ") or ""
                        line.Item:SetText(iconStr .. qtyStr .. itemLinkQ)
                        line.Bind:SetText(GetBindLabel(thisData.itemLink))
                    else
                        local iconStr = itemIcon and ("|T" .. itemIcon .. ":16|t ") or ""
                        line.Item:SetText(iconStr .. "...")
                        line.Bind:SetText("")
                        needsRetry = true
                    end
                else
                    line.Item:SetText("")
                    line.Bind:SetText("")
                end
            end
        end

        if needsRetry and not self.retryTimer then
            self.retryTimer = C_Timer.NewTimer(0.5, function()
                self.retryTimer = nil
                self:Refresh()
            end)
        end
    end

    -- Line creation function
    local scrollLineHeight = 20
    local defaultAmountOfLines = 18

    local function createLineFunc(self, index)
        local line = CreateFrame("button", "$parentLootLine" .. index, self, "BackdropTemplate")
        line.index = index

        line:SetPoint("topleft", self, "topleft", 2, (scrollLineHeight * (index - 1) * -1) - 2)
        line:SetPoint("topright", self, "topright", -2, (scrollLineHeight * (index - 1) * -1) - 2)
        line:SetHeight(scrollLineHeight)

        DF:Mixin(line, DF.HeaderFunctions)
        DF.BackdropUtil:SetColorStripe(line, index)

        local header = self:GetParent().Header

        local dateText = DF:CreateLabel(line, "")
        dateText:SetFont(expressway, 11, "OUTLINE")

        local instanceText = DF:CreateLabel(line, "")
        instanceText:SetFont(expressway, 11, "OUTLINE")

        local bossText = DF:CreateLabel(line, "")
        bossText:SetFont(expressway, 11, "OUTLINE")

        local diffText = DF:CreateLabel(line, "")
        diffText:SetFont(expressway, 11, "OUTLINE")

        local playerText = DF:CreateLabel(line, "")
        playerText:SetFont(expressway, 11, "OUTLINE")

        local bindText = DF:CreateLabel(line, "")
        bindText:SetFont(expressway, 11, "OUTLINE")

        local itemText = DF:CreateLabel(line, "")
        itemText:SetFont(expressway, 11, "OUTLINE")

        line:AddFrameToHeaderAlignment(dateText)
        line:AddFrameToHeaderAlignment(instanceText)
        line:AddFrameToHeaderAlignment(bossText)
        line:AddFrameToHeaderAlignment(diffText)
        line:AddFrameToHeaderAlignment(playerText)
        line:AddFrameToHeaderAlignment(bindText)
        line:AddFrameToHeaderAlignment(itemText)

        line:AlignWithHeader(header, "left")

        line.Date = dateText
        line.Instance = instanceText
        line.Boss = bossText
        line.Difficulty = diffText
        line.Player = playerText
        line.Item = itemText
        line.Bind = bindText

        -- Tooltip on item column only
        local itemHitFrame = CreateFrame("Frame", nil, line)
        itemHitFrame:SetAllPoints(itemText.widget)
        itemHitFrame:EnableMouse(true)
        itemHitFrame:SetScript("OnEnter", function()
            if line.data and line.data.itemLink then
                GameTooltip:SetOwner(itemText.widget, "ANCHOR_CURSOR")
                GameTooltip:SetHyperlink(line.data.itemLink)
                GameTooltip:Show()
                itemHitFrame:SetScript("OnUpdate", function()
                    if IsShiftKeyDown() then
                        GameTooltip_ShowCompareItem()
                    else
                        GameTooltip_HideShoppingTooltips(GameTooltip)
                    end
                end)
            end
        end)
        itemHitFrame:SetScript("OnLeave", function()
            GameTooltip:Hide()
            itemHitFrame:SetScript("OnUpdate", nil)
        end)

        -- Click handler
        line:RegisterForClicks("LeftButtonDown")
        line:SetScript("OnClick", function(self, button)
            if not self.data then return end

            if IsControlKeyDown() then
                -- Delete record
                local posI = self.data.posI
                if not posI then return end

                if not enableDel then
                    StaticPopupDialogs["P1C_LOOTHISTORY_REMOVEONE"] = {
                        text = "Delete this loot record?",
                        button1 = "Yes",
                        button2 = "No",
                        OnAccept = function()
                            enableDel = true
                            tremove(POC.LootHistory.list, posI)
                            LHUI:RefreshData()
                        end,
                        timeout = 0,
                        whileDead = true,
                        hideOnEscape = true,
                        preferredIndex = 3,
                    }
                    StaticPopup_Show("P1C_LOOTHISTORY_REMOVEONE")
                else
                    tremove(POC.LootHistory.list, posI)
                    LHUI:RefreshData()
                end
            elseif self.data.itemLink then
                -- Link item to chat
                local _, itemLink = GetItemInfo(self.data.itemLink)
                if itemLink then
                    ChatEdit_InsertLink(itemLink)
                end
            end
        end)

        return line
    end

    -- ScrollBox
    local scrollbox = DF:CreateScrollBox(resultsFrame, "P1CLootScrollBox", refresh, {}, tabWidth, tabHeight, defaultAmountOfLines, scrollLineHeight)
    DF:ReskinSlider(scrollbox)
    scrollbox.ReajustNumFrames = true
    scrollbox:SetPoint("TOPLEFT", resultsFrame, "TOPLEFT", 0, 0)
    scrollbox:CreateLines(createLineFunc, defaultAmountOfLines)
    scrollbox:Refresh()

    LHUI.scrollbox = scrollbox
    LHUI.currentSearch = function() return currentSearch end

    -- Refresh on show
    parent:SetScript("OnShow", function()
        LHUI:RefreshData()
    end)
end

function LHUI:RefreshData()
    if not self.scrollbox then return end

    local result = {}
    local search = self.currentSearch and self.currentSearch()
    local diffCache = {}

    for i = #POC.LootHistory.list, 1, -1 do
        local parsed = LH:ParseRecord(POC.LootHistory.list[i])

        local instanceName = POC.LootHistory.instanceNames[parsed.instanceID] or ""
        local dateStr = date("%d.%m.%Y %H:%M", parsed.time)

        local bossName = POC.LootHistory.bossNames[parsed.encounterID] or ""
        if parsed.encounterID == 0 then bossName = "" end

        local diffID = parsed.difficulty
        local diffName = diffCache[diffID]
        if diffName == nil then
            diffName = GetDifficultyInfo(diffID) or ""
            diffCache[diffID] = diffName
        end

        local classToken = LH.CLASS_ID_TO_STRING[parsed.classID]
        local rollIcon = (parsed.rollType and LH.ROLL_TYPE_ICONS[parsed.rollType]) or ""
        local playerStr = rollIcon .. (classToken and "|c" .. LH:ClassColor(classToken) or "") .. (parsed.playerName or "") .. "|r"

        local toAdd = true
        if search then
            for _, searchText in ipairs(search) do
                local found = false

                if instanceName:lower():find(searchText, 1, true) then
                    found = true
                elseif dateStr:find(searchText, 1, true) then
                    found = true
                elseif bossName:lower():find(searchText, 1, true) then
                    found = true
                elseif parsed.playerName and parsed.playerName:lower():find(searchText, 1, true) then
                    found = true
                elseif diffName:lower():find(searchText, 1, true) then
                    found = true
                elseif tonumber(searchText) and parsed.itemLink and searchText == parsed.itemLink:match("item:(%d+)") then
                    found = true
                elseif (searchText == "pass" and parsed.rollType == "0") or (searchText == "need" and parsed.rollType == "1") or (searchText == "greed" and parsed.rollType == "2") then
                    found = true
                else
                    local itemName = parsed.itemLink and GetItemInfo(parsed.itemLink)
                    if itemName and itemName:lower():find(searchText, 1, true) then
                        found = true
                    end
                end

                if not found then
                    toAdd = false
                    break
                end
            end
        end

        if toAdd then
            result[#result + 1] = {
                dateStr = dateStr,
                instanceName = instanceName,
                bossName = bossName,
                diffName = diffName,
                playerStr = playerStr,
                itemLink = parsed.itemLink,
                quantity = parsed.quantity,
                posI = i,
            }
        end
    end

    self.scrollbox:SetData(result)
    self.scrollbox:Refresh()
end
