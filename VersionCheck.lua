local _, POI = ... -- Internal namespace

function POI:RequestVersionNumber(type, name) -- type == "Simc" 
    -- todo: only guild officer can do this
    if (UnitIsGroupLeader("player") or UnitIsGroupAssistant("player") or POC.Settings["Debug"]) then
        local unit, ver, duplicate, url = POI:GetVersionNumber(type, name, unit)
        POI:VersionResponse({name = UnitName("player"), version = "No Response", duplicate = false})
        POI:Broadcast("POI_VERSION_REQUEST", "RAID", type, name)
        -- todo: change to iterate guild members
        for unit in POI:IterateGroupMembers() do
            if UnitInRaid(unit) and not UnitIsUnit("player", unit) then
                local index = UnitInRaid(unit) 
                local response = select(8, GetRaidRosterInfo(index)) and "No Response" or "Offline"
                POI:VersionResponse({name = UnitName(unit), version = response, duplicate = false})
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
            simc = POI:GetSimc() or "Note Missing"
        else
            simc = C_AddOns.GetAddOnMetadata("Simulationcraft", "Version") and "Simulationcraft not enabled" or "Simulationcraft not installed"
        end
        return unit, simc, false, ""
    end
end