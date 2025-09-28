local _, POI = ... -- Internal namespace

-- Function from WeakAuras, thanks rivers
function POI:IterateGroupMembers(reversed, forceParty)
    local unit = (not forceParty and IsInRaid()) and 'raid' or 'party'
    local numGroupMembers = unit == 'party' and GetNumSubgroupMembers() or GetNumGroupMembers()
    local i = reversed and numGroupMembers or (unit == 'party' and 0 or 1)
    return function()
        local ret
        if i == 0 and unit == 'party' then
            ret = 'player'
        elseif i <= numGroupMembers and i > 0 then
            ret = unit .. i
        end
        i = i + (reversed and -1 or 1)
        return ret
    end
end

function POI:Print(...)
    if POC.Settings["DebugLogs"] then
        if DevTool then
            local t = {...}
            local name = t[1]
            print("added", name, "to DevTool Logs")
            table.remove(t, 1)
            DevTool:AddData(t, name)
        else
            print(...)
        end
    end
end

function POI:GetUnitGuildInfo(unitName)
    for i = 1,GetNumGuildMembers() do
        local memberNameRealm = GetGuildRosterInfo(i)
        local memberName = memberNameRealm and strsplit("-", memberNameRealm) or nil
		if memberName == unitName then
			return GetGuildRosterInfo(i)
		end
	end
end

function POAPI:Shorten(unit, num, role, AddonName, combined) -- Returns color coded Name/Nickname
    local classFile = unit and select(2, UnitClass(unit)) or select(11, POI:GetUnitGuildInfo(unit))
    if role then -- create role icon if requested
        local specid = 0
        if unit then specid = POAPI:GetSpecs(unit) or WeakAuras.SpecForUnit(unit) or 0 end
        local icon = select(4, GetSpecializationInfoByID(specid))
        if icon then -- if we didn't get the specid can at least try to return the role icon
            role = "\124T"..icon..":12:12:0:0:64:64:4:60:4:60\124t"
        else
            role = UnitGroupRolesAssigned(unit)
            if role ~= "NONE" then
                role = CreateAtlasMarkup(GetIconForRole(role), 0, 0)
            else
                role = ""
            end
        end
    end
    if classFile then -- basically "if unit found"
        local name = UnitName(unit) or unit -- fallback to unit if name not found (eg for guild members name)
        local color = GetClassColorObj(classFile)
        name = num and WeakAuras.WA_Utf8Sub(NSAPI:GetName(name, AddonName), num) or NSAPI:GetName(name, AddonName) -- shorten name before wrapping in color
        if color then -- should always be true anyway?
            return combined and role..color:WrapTextInColorCode(name) or color:WrapTextInColorCode(name), combined and "" or role
        else
            return combined and role..name or name, combined and "" or role
        end
    else
        return unit, "" -- return input if nothing was found
    end
end

function POI:Difficultycheck(encountercheck, num) -- check if current difficulty is a Normal/Heroic/Mythic raid and also allow checking if we are currently in an encounter
    local difficultyID = select(3, GetInstanceInfo()) or 0
    return POC.Settings["Debug"] or ((difficultyID <= 16 and difficultyID >= num) and ((not encountercheck) or POI:EncounterCheck()))
end

function POI:EncounterCheck(skipdebug)
    return WeakAuras.CurrentEncounter or (POC.Settings["Debug"] and not skipdebug)
end

function POAPI:TTS(sound, voice) -- POAPI:TTS("Bait Frontal")
  if POC.Settings["TTS"] then
      local num = voice or POC.Settings["TTSVoice"]
        C_VoiceChat.SpeakText(
                num,
                sound,
                Enum.VoiceTtsDestination.LocalPlayback,
                C_TTSSettings and C_TTSSettings.GetSpeechRate() or 0,
                POC.Settings["TTSVolume"]
        )
     end
end

function POI:GetLootHistoryString(limit)
    if not VMRT then
        return "Please Enable Method Raid Tools"
    end
    if not VMRT.LootHistory or not VMRT.LootHistory.list then
        return "Please Enable \"Loot History\" module in Method Raid Tools"
    end

    local result = ""
    local count = 0
    local total = #VMRT.LootHistory.list
    local maxAllowed = 150

    -- If no limit specified, set to maxAllowed
    if not limit or limit <= 0 then
        POI.Print("GetLootHistoryString: set amount to ", maxAllowed)
        limit = maxAllowed
    end
    limit = math.min(limit, total)

    -- Start from the most recent item and count down
    for i = total, 1, -1 do
        local entry = VMRT.LootHistory.list[i]
        result = result .. entry .. "\n"
        count = count + 1
        if count >= limit then
            break
        end
    end

    return result
end

function POI:GetCompString()
    if not IsInRaid() then
        return "You are not in raid"
    end

    local diff = GetRaidDifficultyID() -- 16 Mythic

    -- in case of normal/hc we take group 1-7
    local upperGroup = 7
    if diff == 16 then
        -- in case of mythic we take group 1-4
        upperGroup = 4
    end

    local myRealm = GetNormalizedRealmName()
    local result = ""
    for i = 1, 40 do
        local namerealm,_,subgroup = GetRaidRosterInfo(i) -- realm info is included only if cross-realm
        if namerealm and subgroup > 0 and subgroup <= upperGroup then
            local name, realm = strsplit("-", namerealm)
            realm = realm or myRealm
            result = result .. name .. "-" .. realm .. "\n"
        end
    end

    return result
end

function AsyncHideSimcFrame()
    POI.Print("Simc hiding async")
    local SimcFrame = _G["SimcFrame"]
    C_Timer.After(0.2, function()
        if SimcFrame then
            _G["SimcFrame"]:Hide()
            POI.SimcHideNext = false
        else
            AsyncHideSimcFrame()
        end
    end)
end

-- Simc wrapping

function POI:GetSimc()
    if not C_AddOns.IsAddOnLoaded("Simulationcraft") then
        print("Addon Simulationcraft is disabled, can't read the profile")
        return "empty"
    end
    Simulationcraft = LibStub("AceAddon-3.0"):GetAddon("Simulationcraft")
    
    -- inject hook
    if not POI.SimcHook then
        POI.SimcHook = true
        hooksecurefunc(Simulationcraft, 'PrintSimcProfile', function()
            local SimcFrame = _G["SimcFrame"]
            if POI.SimcHideNext then
                if SimcFrame then
                    _G["SimcFrame"]:Hide()
                    POI.SimcHideNext = false
                else
                    AsyncHideSimcFrame()
                end
            end
	    end)
    end
    
    POI.SimcHideNext = true
    Simulationcraft:PrintSimcProfile(false, false, false, nil) -- there is no option to direcltly get the text, so we use the editbox it creates......
    local SimcEditBox = _G["SimcEditBox"];
	local simc = SimcEditBox and SimcEditBox.GetText and SimcEditBox:GetText() or "Error during reading"
    --POI.Print("Simc profile generated:", simc)
    return simc
end

-- player currency
function POI:GetUpgradeCurrencies()
    local upgradeCurrencies = {}
    for currencyId, currencyName in pairs(POI.UpgradeCurrencies) do
        local currencyInfo = C_CurrencyInfo.GetCurrencyInfo(currencyId)
        --POI:Print("Currency info", currencyInfo)
        if currencyInfo then
            upgradeCurrencies[currencyId] = {}
            upgradeCurrencies[currencyId].name = currencyName
            upgradeCurrencies[currencyId].currencyID = currencyInfo.currencyID
            upgradeCurrencies[currencyId].quantity = currencyInfo.quantity
            upgradeCurrencies[currencyId].maxQuantity = currencyInfo.maxQuantity
            upgradeCurrencies[currencyId].iconFileID = currencyInfo.iconFileID
            upgradeCurrencies[currencyId].itemLink = C_CurrencyInfo.GetCurrencyLink(currencyInfo.currencyID)
        end
    end
    return upgradeCurrencies
end

-- player weekly reward
function POI:GetWeeklyRewards()
    local WeeklyRewards = _G.C_WeeklyRewards
    local res = {}

    POI:Print("Weekly reward", WeeklyRewards)

    if not WeeklyRewards then
        POI:Print("WeeklyRewards not available")
        return res
    end

    if WeeklyRewards:HasAvailableRewards() then
        if not WeeklyRewards:AreRewardsForCurrentRewardPeriod() then
            POI:Print("WeeklyRewards not from this week")
            return res
        end
        -- Weekly reward not yet generated/interacted
        if not WeeklyRewards:HasGeneratedRewards() then
            POI:Print("WeeklyRewards not opened yet", WeeklyRewards)
            return res
        end
        local activities = WeeklyRewards.GetActivities()
        for _, activityInfo in ipairs(activities) do
            for _, rewardInfo in ipairs(activityInfo.rewards) do
                local _, _, _, itemEquipLoc = C_Item.GetItemInfoInstant(rewardInfo.id)
                if rewardInfo.type == Enum.CachedRewardType.Item and itemEquipLoc and itemEquipLoc ~= "INVTYPE_NON_EQUIP_IGNORE" then
                    POI:Print("Reward info", rewardInfo,itemEquipLoc )
                    table.insert(res, rewardInfo)
                end
            end
        end
    else
        POI:Print("WeeklyRewards already picked")
        return "ALREADY_PICKED"
    end
    return res
end
