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

function POAPI:Shorten(unit, num, role, AddonName, combined) -- Returns color coded Name/Nickname
    local classFile = unit and select(2, UnitClass(unit))
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
        local name = UnitName(unit)
        local color = GetClassColorObj(classFile)
        name = num and WeakAuras.WA_Utf8Sub(POAPI:GetName(name, AddonName), num) or POAPI:GetName(name, AddonName) -- shorten name before wrapping in color
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

function POI:GetSimc()
    if not C_AddOns.IsAddOnLoaded("Simulationcraft") then
        print("Addon Simulationcraft is disabled, can't read the profile")
        return "empty"
    end
    Simulationcraft = LibStub("AceAddon-3.0"):GetAddon("Simulationcraft")
    Simulationcraft:PrintSimcProfile(false, false, false, nil) -- there is no option to direcltly get the text, so we use the editbox it creates......
    local SimcEditBox = _G["SimcEditBox"];
    local SimcFrame = _G["SimcFrame"];
	local simc = SimcEditBox and SimcEditBox.GetText and SimcEditBox:GetText();
    SimcFrame:Hide()
    POI.Print("Simc profile generated:", simc)
    return simc
end