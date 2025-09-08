local _, POI = ... -- Internal namespace

SLASH_POUI1 = "/p1"
SlashCmdList["POUI"] = function(msg)
    if msg == "comp" then
        POI:ExportCompPopup()
    elseif msg == "wipe" then
        wipe(POC)
        ReloadUI()
    elseif msg == "loot" then
        POI:ExportLootsPopup(100)
    elseif msg == "simc" then
        POI:GetSimc()
    elseif msg == "display" then
        POAPI:DisplayText("Display text", 8)
    elseif msg == "debug" then
        if POC.Settings["Debug"] then
            POC.Settings["Debug"] = false
            print("|cFF00FFFFPOC|r Debug mode is now disabled")
        else
            POC.Settings["Debug"] = true
            print("|cFF00FFFFPOC|r Debug mode is now enabled, please disable it when you are done testing.")
        end
    elseif msg == "minimap" then
        if POC.Settings["Minimap"] then
            POC.Settings["Minimap"].hide = false
            print("|cFF00FFFFPOC|r Minimap icon is now disabled")
        else
            POC.Settings["Minimap"].hide = true
            print("|cFF00FFFFPOC|r Minimap icon is now enabled, please disable it when you are done testing.")
        end
    else
        POI.POUI:ToggleOptions()
    end
end