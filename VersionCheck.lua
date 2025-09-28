local _, POI = ... -- Internal namespace

function POI:RequestPlayersInfo(type, charName) -- type == "Simc" 
    local _, _, guildRankIndex = GetGuildInfo("player"); -- 0 guild master, 1 officer, 2 officer alt
    if (guildRankIndex > 2 and not POC.Settings["Debug"]) then return end -- no permission
    
    -- fill with my own info first 
    if not charName or UnitIsUnit("player", charName) then
        local simc, vault, currencies = POI:GetVersionNumber(type)
        POI:VersionResponse({name = UnitName("player"), simc = simc, vault = vault, currencies = currencies})
    end
    
    if charName then
        if not UnitIsUnit("player", charName) then
            -- Broadcast the request to specific memeber
            POI:Broadcast("POI_VERSION_REQUEST", "WHISPER", charName, type)
            -- Pre-populate with dummy data for char
            POI:VersionResponse({name = charName, simc = "No Response", vault = "No Response", currencies = "No Response"})
        end
    else
        -- Broadcast the request to all members in guild
        POI:Broadcast("POI_VERSION_REQUEST", "GUILD", type)
        -- Iterate all guild members to set their initial status as "No Response"
        local numMembers = GetNumGuildMembers()
        for i = 1, numMembers do
            local memberNameRealm, _, rankIndex, _, _, _, _, _, online = GetGuildRosterInfo(i)
            local memberName = memberNameRealm and strsplit("-", memberNameRealm) or nil
            -- Only include members who are online and not the player
            -- 0 gm, 1 officer, 2 officer alt, 3 member, 4 alt, 5 trial
            if (rankIndex <= 3 or rankIndex == 5) and online and not UnitIsUnit("player", memberName) then
                POI:VersionResponse({name = memberName, simc = "No Response", vault = "No Response", currencies = "No Response"})
            end
        end
    end
end

function POI:VersionResponse(data)
    POI.POUI.version_scrollbox:AddData(data)
end

function POI:GetVersionNumber(type)
    if type == "Simc" then
        local simc
        local currencies = POI:GetUpgradeCurrencies()
        local vault = POI:GetWeeklyRewards()
        if C_AddOns.IsAddOnLoaded("Simulationcraft") then
            --simc = POI:GetSimc()
            simc = "" -- until simc fix his shit
            currencies = POI:GetUpgradeCurrencies()
            vault = POI:GetWeeklyRewards()
        else
            simc = C_AddOns.GetAddOnMetadata("Simulationcraft", "Version") and "Simulationcraft not enabled" or "Simulationcraft not installed"
        end
        --POI:Print("GetVersionNumber", unit, simc, vault, currencies)
        return simc, vault, currencies
    end
end