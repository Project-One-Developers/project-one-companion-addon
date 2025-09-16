local _, POI = ... -- Internal namespace

-- function POI:RequestVersionNumber(type, name) -- type == "Simc" 
--     -- todo: only guild officer can do this
--     if (UnitIsGroupLeader("player") or UnitIsGroupAssistant("player") or POC.Settings["Debug"]) then
--         local unit, ver, duplicate, url = POI:GetVersionNumber(type, name, "player")
--         POI:VersionResponse({name = UnitName("player"), version = "No Response", duplicate = false})
--         POI:Broadcast("POI_VERSION_REQUEST", "RAID", type, name)
--         -- todo: change to iterate guild members
--         for unit in POI:IterateGroupMembers() do
--             if UnitInRaid(unit) and not UnitIsUnit("player", unit) then
--                 local index = UnitInRaid(unit) 
--                 local response = select(8, GetRaidRosterInfo(index)) and "No Response" or "Offline"
--                 POI:VersionResponse({name = UnitName(unit), version = response, duplicate = false})
--             end
--         end
--         return {name = UnitName("player"), version = ver, duplicate = duplicate}, url
--     end
-- end

function POI:RequestVersionNumber(type, name) -- type == "Simc" 
    POI.Print("RequestVersionNumber called", type, name)
    local _, _, guildRankIndex = GetGuildInfo("player"); -- 0 guild master, 1 officer, 2 officer alt
    if (guildRankIndex <= 2 or POC.Settings["Debug"]) then
        local unit, ver, duplicate, url = POI:GetVersionNumber(type, name, "player")
        -- Pre-populate with my own info first
        POI:VersionResponse({name = UnitName("player"), version = ver, duplicate = duplicate})
        -- Broadcast the request to all members in the raid or group
        POI:Broadcast("POI_VERSION_REQUEST", "RAID", type, name)
        -- Iterate all guild members to set their initial status as "No Response"
        local numMembers = GetNumGuildMembers()
        for i = 1, numMembers do
            local memberNameRealm, _, rankIndex, _, _, _, _, _, online = GetGuildRosterInfo(i)
            local memberName = memberNameRealm and strsplit("-", memberNameRealm) or nil
            -- Only include members who are online and not the player
            -- 0 gm, 1 officer, 2 officer alt, 3 member, 4 alt, 5 trial
            if (rankIndex <= 3 or rankIndex == 5) and online and not UnitIsUnit("player", memberName) then
                POI:VersionResponse({name = memberName, version = "No Response", duplicate = false})
            end
        end
        return {name = UnitName("player"), version = ver, duplicate = duplicate}, url
    end
end

function POI:VersionResponse(data)
    POI.POUI.version_scrollbox:AddData(data)
end

function POI:GetVersionNumber(type, name, unit)
    if type == "Simc" then
        local simc
        if C_AddOns.IsAddOnLoaded("Simulationcraft") then
            simc = POI:GetSimc()
        else
            simc = C_AddOns.GetAddOnMetadata("Simulationcraft", "Version") and "Simulationcraft not enabled" or "Simulationcraft not installed"
        end
        return unit, simc, false, ""
    end
end