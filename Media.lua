local _, POI = ... -- Internal namespace
local LSM = LibStub("LibSharedMedia-3.0")
POMedia = {}

--Sounds
LSM:Register("sound","|cFF034077Allegria|r", [[Interface\Addons\P1Companion\Media\Sounds\allegria.ogg]])

--Fonts
LSM:Register("font","Expressway", [[Interface\Addons\P1Companion\Media\Fonts\Expressway.TTF]])

-- Open WA Options
function POMedia.OpenWA()
    WeakAuras.OpenOptions()
end

-- Memes for Break-Timer
POMedia.BreakMemes = {
    --{[[Interface\AddOns\P1Companion\Media\Memes\ZarugarPeace.blp]], 256, 256},
}

-- Memes for WA updating
POMedia.UpdateMemes = {
    --{[[Interface\AddOns\P1Companion\Media\Memes\ZarugarPeace.blp]], 256, 256},
}
