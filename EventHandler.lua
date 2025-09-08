local _, POI = ... -- Internal namespace
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_ENTERING_WORLD")

f:SetScript("OnEvent", function(self, e, ...)
    POI:EventHandler(e, true, false, ...)
end)

function POI:EventHandler(e, wowevent, internal, ...) -- internal checks whether the event comes from addon comms. We don't want to allow blizzard events to be fired manually
    if e == "ADDON_LOADED" and wowevent then
        local name = ...
        if name == "P1Companion" then
            if not POC then POC = {} end
            if not POC.POUI then POC.POUI = {scale = 1} end
            if not POC.Settings then POC.Settings = {} end
            POC.Settings["WeakAurasImportAccept"] = POC.Settings["WeakAurasImportAccept"] or 1 -- guild default
            if POC.Settings["TTS"] == nil then POC.Settings["TTS"] = true end
            POC.Settings["TTSVolume"] = POC.Settings["TTSVolume"] or 50
            POC.Settings["TTSVoice"] = POC.Settings["TTSVoice"] or 2
            POC.Settings["Minimap"] = POC.Settings["Minimap"] or {hide = false}
            POC.Settings["AutoUpdateWA"] = POC.Settings["AutoUpdateWA"] or false
            POC.Settings["Debug"] = POC.Settings["Debug"] or false
            POC.Settings["DebugLogs"] = POC.Settings["DebugLogs"] or false
            POC.POUI.AutoComplete = POC.POUI.AutoComplete or {}
            POC.POUI.AutoComplete["WA"] = POC.POUI.AutoComplete["WA"] or {}
            POC.POUI.AutoComplete["Addon"] = POC.POUI.AutoComplete["Addon"] or {}
        end
    elseif e == "PLAYER_ENTERING_WORLD" and wowevent then
        --POI:AutoImport()
    elseif e == "PLAYER_LOGIN" and wowevent then
        POI.POUI:Init()
        POI:InitLDB()
        if POC.Settings["Debug"] then
            print("|cFF00FFFFPOC|r Debug mode is currently enabled. Please disable it with '/ns debug' unless you are specifically testing something.")
        end
    elseif e == "POI_VERSION_CHECK" and (internal or POC.Settings["Debug"]) then
        if WeakAuras.CurrentEncounter then return end
        local unit, ver, duplicate = ...        
        POI:VersionResponse({name = UnitName(unit), version = ver, duplicate = duplicate})
    elseif e == "POI_VERSION_REQUEST" and (internal or POC.Settings["Debug"]) then
        if WeakAuras.CurrentEncounter then return end
        local unit, type, name = ...        
        if UnitExists(unit) and UnitIsUnit("player", unit) then return end -- don't send to yourself
        if (GetGuildInfo(unit) == GetGuildInfo("player")) then -- only accept this from same guild to prevent abuse
            local u, ver, duplicate = POI:GetVersionNumber(type, name, unit)
            POI:Broadcast("POI_VERSION_CHECK", "WHISPER", unit, ver, duplicate)
        end
    end
end