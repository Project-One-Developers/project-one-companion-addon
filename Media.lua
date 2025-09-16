local _, POI = ... -- Internal namespace
local LSM = LibStub("LibSharedMedia-3.0")
POMedia = {}

--Sounds
LSM:Register("sound","|cFF034077Aggro|r", [[Interface\Addons\P1Companion\Media\Sounds\aggro.mp3]])
LSM:Register("sound","|cFF034077Allegria|r", [[Interface\Addons\P1Companion\Media\Sounds\allegria.ogg]])
LSM:Register("sound","|cFF034077Backup|r", [[Interface\Addons\P1Companion\Media\Sounds\backup.mp3]])
LSM:Register("sound","|cFF034077BarraAAAA|r", [[Interface\Addons\P1Companion\Media\Sounds\barra-aaaaaaaa.ogg]])
LSM:Register("sound","|cFF034077Grissinbon|r", [[Interface\Addons\P1Companion\Media\Sounds\grissinbon.ogg]])
LSM:Register("sound","|cFF034077Letto|r", [[Interface\Addons\P1Companion\Media\Sounds\letto.ogg]])
LSM:Register("sound","|cFF034077MagoFrost|r", [[Interface\Addons\P1Companion\Media\Sounds\mago-frost.mp3]])
LSM:Register("sound","|cFF034077Mavaman|r", [[Interface\Addons\P1Companion\Media\Sounds\mavaman.mp3]])
LSM:Register("sound","|cFF034077Pekke|r", [[Interface\Addons\P1Companion\Media\Sounds\pekke.ogg]])
LSM:Register("sound","|cFF034077Rune|r", [[Interface\Addons\P1Companion\Media\Sounds\rune.mp3]])
LSM:Register("sound","|cFF034077Sce|r", [[Interface\Addons\P1Companion\Media\Sounds\sce.mp3]])
LSM:Register("sound","|cFF034077Sennochefai|r", [[Interface\Addons\P1Companion\Media\Sounds\sennochefai.mp3]])
LSM:Register("sound","|cFF034077Unreal|r", [[Interface\Addons\P1Companion\Media\Sounds\unreal.mp3]])
LSM:Register("sound","|cFF034077UwU|r", [[Interface\Addons\P1Companion\Media\Sounds\uwu.mp3]])

--Fonts
LSM:Register("font","Expressway", [[Interface\Addons\P1Companion\Media\Fonts\Expressway.TTF]])

-- Memes for Break-Timer
POMedia.BreakMemes = {
    {[[Interface\AddOns\P1Companion\Media\Memes\nepe-cinghiale.blp]], 256, 256},
    {[[Interface\AddOns\P1Companion\Media\Memes\wildi-sara.blp]], 256, 256},
    {[[Interface\AddOns\P1Companion\Media\Memes\zorby-back.blp]], 256, 256},
    {[[Interface\AddOns\P1Companion\Media\Memes\ghuun.blp]], 256, 256},
    {[[Interface\AddOns\P1Companion\Media\Memes\soul-toy.blp]], 256, 256},
    {[[Interface\AddOns\P1Companion\Media\Memes\sprocket.blp]], 256, 256},
}

-- Memes for WA updating
POMedia.UpdateMemes = {
    --{[[Interface\AddOns\P1Companion\Media\Memes\ZarugarPeace.blp]], 256, 256},
}

-- Open WA Options
function POMedia.OpenWA()
    WeakAuras.OpenOptions()
end

local function rndMedia(t)
    -- Check if the input is a valid non-empty table
    if type(t) ~= "table" or #t == 0 then
        return nil
    end

    -- Get the current minutes from the game time
    local time = GetServerTime()
    local minutes = Round((tonumber(date("%M", time)) / 5))
    
    -- The + 1 is crucial to adjust for Lua's 1-based indexing
    local rndIdx = (minutes % #t) + 1

    return t[rndIdx]
end

function POMedia.BreakMemesEnabled()
    return POC.Settings["MemeBreakTimer"]
end

function POMedia.RndBreakMemes(trueRandom)
    if not POC.Settings["MemeBreakTimer"] then
        return nil
    end
    local selectedMedia = trueRandom and POMedia.BreakMemes[math.random(1, #POMedia.BreakMemes)] or rndMedia(POMedia.BreakMemes)
    return selectedMedia[1] -- first element is the path
end