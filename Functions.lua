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

function POAPI:Shorten(unit, num, specicon, AddonName, combined, roleicon) -- Returns color coded Name/Nickname
    local classFile = unit and select(2, UnitClass(unit))
    if specicon then
        local specid = 0
        if unit then specid = NSAPI:GetSpecs(unit) or 0 end
        local icon = select(4, GetSpecializationInfoByID(specid))
        if icon then 
            specicon = "\124T"..icon..":12:12:0:0:64:64:4:60:4:60\124t"
        elseif not roleicon then -- if we didn't get the specid can at least try to return the role icon unless that one was specifically requested as well
            specicon = UnitGroupRolesAssigned(unit)
            if specicon ~= "NONE" then
                specicon = CreateAtlasMarkup(GetIconForRole(specicon), 0, 0)
            else
                specicon = ""
            end
        else
            specicon = ""
        end
    else
        specicon = ""
    end
    if roleicon then
        roleicon = UnitGroupRolesAssigned(unit)
        if roleicon ~= "NONE" then
            roleicon = CreateAtlasMarkup(GetIconForRole(roleicon), 0, 0)
        else
            roleicon = ""
        end
    else
        roleicon = ""
    end
    if classFile then -- basically "if unit found"
        local name = UnitName(unit)
        local color = GetClassColorObj(classFile)
        name = num and POI:Utf8Sub(NSAPI:GetName(name, AddonName), 1, num) or NSAPI:GetName(name, AddonName) -- shorten name before wrapping in color
        if color then -- should always be true anyway?
            return combined and specicon..roleicon..color:WrapTextInColorCode(name) or color:WrapTextInColorCode(name), combined and "" or specicon, combined and "" or roleicon
        else
            return combined and specicon..roleicon..name or name, combined and "" or specicon, combined and "" or roleicon
        end
    else
        return unit, "", "" -- return input if nothing was found
    end
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

function POI:Utf8Sub(str, startChar, endChar)
    if not str then return str end
    local startIndex, endIndex = 1, #str
    local currentIndex, currentChar = 1, 0

    while currentIndex <= #str do
        currentChar = currentChar + 1

        if currentChar == startChar then
            startIndex = currentIndex
        end
        if endChar and currentChar > endChar then
            endIndex = currentIndex - 1
            break
        end
        
        local c = string.byte(str, currentIndex)
        if c < 0x80 then
            currentIndex = currentIndex + 1
        elseif c < 0xE0 then
            currentIndex = currentIndex + 2
        elseif c < 0xF0 then
            currentIndex = currentIndex + 3
        else
            currentIndex = currentIndex + 4
        end
    end

    return string.sub(str, startIndex, endIndex)
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
