local _, POI = ... -- Project One Internal namespace
_G["POAPI"] = {}

local LDB = LibStub("LibDataBroker-1.1")
local LDBIcon = LDB and LibStub("LibDBIcon-1.0")

function POI:InitLDB()
    if LDB then
        local databroker = LDB:NewDataObject("POC", {
            type = "launcher",
            label = "Project One Companion",
            icon = [[Interface\AddOns\P1Companion\Media\P1Logo]],
            showInCompartment = true,
            OnClick = function(self, button)
                if button == "LeftButton" then
                    POI.POUI:ToggleOptions()
                end
            end,
            OnTooltipShow = function(tooltip)
                tooltip:AddLine("Project One Companion", 0, 1, 1)
                tooltip:AddLine("|cFFCFCFCFLeft click|r: Show/Hide Options Window")
            end
        })

        if (databroker and not LDBIcon:IsRegistered("POC")) then
            LDBIcon:Register("POC", databroker, POC.Settings["Minimap"])
            LDBIcon:AddButtonToCompartment("POC")
        end

        POI.databroker = databroker
    end
end
