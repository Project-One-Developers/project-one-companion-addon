local _, POI = ... -- Internal namespace
local AceComm = LibStub("AceComm-3.0")
local LibSerialize = LibStub("LibSerialize")
local LibDeflate = LibStub("LibDeflate")
local allowedGuildComms = {
    ["POI_VERSION_REQUEST"] = true,
}

local del = ":"

function POI:Broadcast(event, channel, ...) -- using internal broadcast function for anything inside the addon to prevent users to send stuff they shouldn't be sending
    local message = event
    local argTable = {...}
    local target = ""

    local argCount = #argTable
    -- Always send unitID as second argument after event
    local unitID = UnitInRaid("player") and "raid"..UnitInRaid("player") or UnitName("player")
    message = string.format("%s"..del.."%s(%s)", message, unitID, "string")


    for i = 1, argCount do
        local functionArg = argTable[i]
        local argType = type(functionArg)

        if argType == "table" then
            functionArg = LibSerialize:Serialize(functionArg)
            functionArg = LibDeflate:CompressDeflate(functionArg)
            functionArg = LibDeflate:EncodeForWoWAddonChannel(functionArg)
            message = string.format("%s"..del.."%s(%s)", message, tostring(functionArg), argType)
        else
            if argType ~= "string" and argType ~= "number" and argType ~= "boolean" then
                functionArg = ""
                argType = "string"
            end
            message = string.format("%s"..del.."%s(%s)", message, tostring(functionArg), argType)
        end
    end
    if channel == "WHISPER" then -- create "fake" whisper addon msg that actually just uses GUILD instead and will be checked on receive
        AceComm:SendCommMessage("POI_WHISPER", message, "GUILD")
    else
        AceComm:SendCommMessage("POI_MSG", message, channel)
    end
end

local function ReceiveComm(text, chan, sender, whisper, internal)
    local argTable = {strsplit(del, text)}
    local event = argTable[1]
    if (UnitExists(sender) and (UnitInRaid(sender) or UnitInParty(sender))) or (chan == "GUILD" and allowedGuildComms[event]) then -- block addon msg's from outside the raid, only exception being the guild nickname comms. 
        local formattedArgTable = {}
        table.remove(argTable, 1)
        
        -- if comm is tagged as "whisper" then check if the whisper target is actually yourself, otherwise ignore the message
        if whisper then
            local target, argType = argTable[2]:match("(.*)%((%a+)%)") -- initially first entry is event, 2nd the unitid of the sender and 3rd the whisper target but we already removed first table entry
            if not (UnitIsUnit("player", target)) then
                return
            end
            table.remove(argTable, 2)
        end

        local tonext
        for i, functionArg in ipairs(argTable) do
            local argValue, argType = functionArg:match("(.*)%((%a+)%)")
            if tonext and argValue then argValue = tonext..argValue end
            if argType == "number" then
                argValue = tonumber(argValue)
                tonext = nil
            elseif argType == "boolean" then
                argValue = argValue == "true" or false
                tonext = nil
            elseif argType == "table" then
                argValue = LibDeflate:DecodeForWoWAddonChannel(argValue)
                argValue = LibDeflate:DecompressDeflate(argValue)
                local success, t = LibSerialize:Deserialize(argValue)
                if success then
                    argValue = t
                else
                    argValue = ""
                end
                tonext = nil
            end
            if (argValue or argValue == false) and argType then
                if argValue == "" then
                    table.insert(formattedArgTable, false)
                else
                    table.insert(formattedArgTable, argValue)
                end
                tonext = nil
            end
            if not argType then
                tonext = tonext or ""
                tonext = tonext..functionArg..del -- if argtype wasn't given then this is part of a table that was falsely split by the delimeter so we're stitching it back together
            end
        end
        POI:EventHandler(event, false, internal, unpack(formattedArgTable))
    end
end


AceComm:RegisterComm("POI_MSG", function(_, text, chan, sender) ReceiveComm(text, chan, sender, false, true) end)
AceComm:RegisterComm("POI_WHISPER", function(_, text, chan, sender) ReceiveComm(text, chan, sender, true, true) end)


-- POAPI:Broadcast("NS_EVENTNAME", channel, targetunitID if whisper, arg1, arg2, arg3)