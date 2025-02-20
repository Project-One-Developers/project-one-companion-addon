-- Ignore some luacheck warnings about global vars, just use a ton of them in WoW Lua
-- luacheck: no global
-- luacheck: no self
local _, P1Companion = ...

P1Companion = LibStub("AceAddon-3.0"):NewAddon(P1Companion, "P1Companion", "AceConsole-3.0", "AceEvent-3.0")
LibRealmInfo = LibStub("LibRealmInfo")

LibDBIcon = LibStub("LibDBIcon-1.0")

local SimcFrame = nil
local OptionsDB = nil

-- Set up DataBroker for minimap button
SimcLDB = LibStub("LibDataBroker-1.1"):NewDataObject("P1Companion", {
  type = "data source",
  text = "P1Companion",
  label = "P1Companion",
  icon = "Interface\\AddOns\\P1Companion\\logo",
  OnClick = function()
    if SimcFrame and SimcFrame:IsShown() then
      SimcFrame:Hide()
    else
      P1Companion:PrintSimcProfile()
    end
  end,
  OnTooltipShow = function(tt)
    tt:AddLine("P1 Companion")
    tt:AddLine(" ")
    tt:AddLine("Click to show loots")
    tt:AddLine("To toggle minimap button, type '/simc minimap'")
  end
})

-- Most of the guts of this addon were based on a variety of other ones, including
-- Statslog, AskMrRobot, and BonusScanner. And a bunch of hacking around with AceGUI.
-- Many thanks to the authors of those addons, and to reia for fixing my awful amateur
-- coding mistakes regarding objects and namespaces.

function P1Companion:OnInitialize()
  -- init databroker
  OptionsDB = LibStub("AceDB-3.0"):New("P1CompanionDB", {
    profile = {
      minimap = {
        hide = false,
      },
      closeOnCopy = true,
      frame = {
        point = "CENTER",
        relativeFrame = nil,
        relativePoint = "CENTER",
        ofsx = 0,
        ofsy = 0,
        width = 750,
        height = 400,
      },
    },
  });
  LibDBIcon:Register("P1Companion", SimcLDB, OptionsDB.profile.minimap)
  P1Companion:UpdateMinimapButton()
  P1Companion:RegisterChatCommand('p1', 'HandleChatCommand')
  AddonCompartmentFrame:RegisterAddon({
    text = "P1Companion",
    icon = "Interface\\AddOns\\P1Companion\\logo",
    notCheckable = true,
    func = function()
      P1Companion:PrintSimcProfile()
    end,
  })
end

function P1Companion:OnEnable()

end

function P1Companion:OnDisable()

end


function P1Companion:HandleChatCommand(input)
  local args = {strsplit(' ', input)}

  local limit = nil
  
  for i = 1, #args do
    local arg = args[i]
    if arg == 'loot' then
      -- Check if next argument is a number
      if args[i + 1] and tonumber(args[i + 1]) then
        limit = tonumber(args[i + 1])
      end
      self:PrintSimcProfile(limit)
      return
    elseif arg == 'minimap' then
      OptionsDB.profile.minimap.hide = not OptionsDB.profile.minimap.hide
      DEFAULT_CHAT_FRAME:AddMessage(
        "P1Companion: Minimap button is now " .. (OptionsDB.profile.minimap.hide and "hidden" or "shown")
      )
      P1Companion:UpdateMinimapButton()
      return
    end
  end
end

function P1Companion:UpdateMinimapButton()
  if (OptionsDB.profile.minimap.hide) then
    LibDBIcon:Hide("P1Companion")
  else
    LibDBIcon:Show("P1Companion")
  end
end

-- =================== Item Information =========================



function P1Companion:GetMainFrame(text)
  -- Frame code largely adapted from https://www.wowinterface.com/forums/showpost.php?p=323901&postcount=2
  if not SimcFrame then
    -- Main Frame
    local frameConfig = OptionsDB.profile.frame
    local f = CreateFrame("Frame", "SimcFrame", UIParent, "DialogBoxFrame")
    f:ClearAllPoints()
    -- load position from local DB
    f:SetPoint(
      frameConfig.point,
      frameConfig.relativeFrame,
      frameConfig.relativePoint,
      frameConfig.ofsx,
      frameConfig.ofsy
    )
    f:SetSize(frameConfig.width, frameConfig.height)
    f:SetBackdrop({
      bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
      edgeFile = "Interface\\PVPFrame\\UI-Character-PVP-Highlight",
      edgeSize = 16,
      insets = { left = 8, right = 8, top = 8, bottom = 8 },
    })
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:SetScript("OnMouseDown", function(self, button) -- luacheck: ignore
      if button == "LeftButton" then
        self:StartMoving()
      end
    end)
    f:SetScript("OnMouseUp", function(self, _) -- luacheck: ignore
      self:StopMovingOrSizing()
      -- save position between sessions
      local point, relativeFrame, relativeTo, ofsx, ofsy = self:GetPoint()
      frameConfig.point = point
      frameConfig.relativeFrame = relativeFrame
      frameConfig.relativePoint = relativeTo
      frameConfig.ofsx = ofsx
      frameConfig.ofsy = ofsy
    end)

    -- scroll frame
    local sf = CreateFrame("ScrollFrame", "SimcScrollFrame", f, "UIPanelScrollFrameTemplate")
    sf:SetPoint("LEFT", 16, 0)
    sf:SetPoint("RIGHT", -32, 0)
    sf:SetPoint("TOP", 0, -32)
    sf:SetPoint("BOTTOM", SimcFrameButton, "TOP", 0, 0)

    -- edit box
    local ctrlDown = false
    local eb = CreateFrame("EditBox", "SimcEditBox", SimcScrollFrame)
    eb:SetSize(sf:GetSize())
    eb:SetMultiLine(true)
    eb:SetAutoFocus(true)
    eb:SetFontObject("ChatFontNormal")
    eb:SetScript("OnEscapePressed", function() f:Hide() end)
    eb:SetScript("OnKeyDown", function(self, key)
      if key == "LCTRL" or key == "RCTRL" then
        ctrlDown = true
      end
    end)
    eb:SetScript("OnKeyUp", function(self, key)
      if key == "LCTRL" or key == "RCTRL" then
        -- Add a small grace period. In testing, the way I press Ctrl-C would sometimes have Ctrl keyup bfore C
        C_Timer.After(0.2, function() ctrlDown = false end)
      end
      if ctrlDown and key == "C" then
        if OptionsDB.profile.closeOnCopy then
          -- Just in case there's some weird way that WoW could close the window before the OS copies
          C_Timer.After(0.1, function()
            f:Hide()
          end)
        end
      end
    end)
    sf:SetScrollChild(eb)

    -- resizing
    f:SetResizable(true)
    if f.SetMinResize then
      -- older function from shadowlands and before
      -- Can remove when Dragonflight is in full swing
      f:SetMinResize(150, 100)
    else
      -- new func for dragonflight
      f:SetResizeBounds(150, 100, nil, nil)
    end
    local rb = CreateFrame("Button", "SimcResizeButton", f)
    rb:SetPoint("BOTTOMRIGHT", -6, 7)
    rb:SetSize(16, 16)

    rb:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    rb:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    rb:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")

    rb:SetScript("OnMouseDown", function(self, button) -- luacheck: ignore
        if button == "LeftButton" then
            f:StartSizing("BOTTOMRIGHT")
            self:GetHighlightTexture():Hide() -- more noticeable
        end
    end)
    rb:SetScript("OnMouseUp", function(self, _) -- luacheck: ignore
        f:StopMovingOrSizing()
        self:GetHighlightTexture():Show()
        eb:SetWidth(sf:GetWidth())

        -- save size between sessions
        frameConfig.width = f:GetWidth()
        frameConfig.height = f:GetHeight()
    end)

    -- Automatic close checkbox
    local checkbox = CreateFrame("CheckButton", "AutomaticClose", f, "ChatConfigCheckButtonTemplate")
    checkbox:SetPoint("BOTTOMLEFT", 12, 18)
    checkbox.Text:SetText("Close after copy")
    checkbox:SetChecked(true)
    checkbox:HookScript("OnClick", function(self)
      OptionsDB.profile.closeOnCopy = self:GetChecked()
    end)

    SimcFrame = f
  end
  SimcEditBox:SetText(text)
  SimcEditBox:HighlightText()
  return SimcFrame
end

-- function P1Companion:GetSimcProfile(debugOutput, noBags, showMerchant, links)
--   -- addon metadata
--   local versionComment = '# SimC Addon ' .. GetAddOnMetadata('P1Companion', 'Version')
--   local wowVersion, wowBuild, _, wowToc = GetBuildInfo()
--   local wowVersionComment = '# WoW ' .. wowVersion .. '.' .. wowBuild .. ', TOC ' .. wowToc
--   local simcVersionWarning = '# Requires P1Companion 1000-01 or newer'

--   -- Basic player info
--   local _, realmName, _, _, _, _, region, _, _, realmLatinName, _ = LibRealmInfo:GetRealmInfoByUnit('player')

--   local playerName = UnitName('player')
--   local _, playerClass = UnitClass('player')
--   local playerLevel = UnitLevel('player')

--   -- Try Latin name for Russian servers first, then realm name from LibRealmInfo, then Realm Name from the game
--   -- Latin name for Russian servers as most APIs use the latin name, not the cyrillic name
--   local playerRealm = realmLatinName or realmName or GetRealmName()

--   -- Try region from LibRealmInfo first, then use default API
--   -- Default API can be wrong for region-switching players
--   local playerRegion = region or GetCurrentRegionName() or regionString[GetCurrentRegion()]

--   -- Race info
--   local _, playerRace = UnitRace('player')

--   -- fix some races to match SimC format
--   if playerRace == 'Scourge' then --lulz
--     playerRace = 'Undead'
--   else
--     playerRace = FormatRace(playerRace)
--   end

--   local isZandalariTroll = false
--   if Tokenize(playerRace) == 'zandalari_troll' then
--     isZandalariTroll = true
--   end

--   -- Spec info
--   local role, globalSpecID, playerRole
--   local specId = GetSpecialization()
--   if specId then
--     globalSpecID,_,_,_,_,role = GetSpecializationInfo(specId)
--   end
--   local playerSpec = specNames[ globalSpecID ] or 'unknown'

--   -- Professions
--   local pid1, pid2 = GetProfessions()
--   local firstProf, firstProfRank, secondProf, secondProfRank, profOneId, profTwoId
--   if pid1 then
--     _,_,firstProfRank,_,_,_,profOneId = GetProfessionInfo(pid1)
--   end
--   if pid2 then
--     _,_,secondProfRank,_,_,_,profTwoId = GetProfessionInfo(pid2)
--   end

--   firstProf = profNames[ profOneId ]
--   secondProf = profNames[ profTwoId ]

--   local playerProfessions = '' -- luacheck: ignore
--   if pid1 or pid2 then
--     playerProfessions = 'professions='
--     if pid1 then
--       playerProfessions = playerProfessions..Tokenize(firstProf)..'='..tostring(firstProfRank)..'/'
--     end
--     if pid2 then
--       playerProfessions = playerProfessions..Tokenize(secondProf)..'='..tostring(secondProfRank)
--     end
--   else
--     playerProfessions = ''
--   end

--   -- create a header comment with basic player info and a date
--   local headerComment = (
--     "# " .. playerName .. ' - ' .. playerSpec
--     .. ' - ' .. date('%Y-%m-%d %H:%M') .. ' - '
--     .. playerRegion .. '/' .. playerRealm
--  )


--   -- Construct SimC-compatible strings from the basic information
--   local player = Tokenize(playerClass) .. '="' .. playerName .. '"'
--   playerLevel = 'level=' .. playerLevel
--   playerRace = 'race=' .. Tokenize(playerRace)
--   playerRole = 'role=' .. TranslateRole(globalSpecID, role)
--   local playerSpecStr = 'spec=' .. Tokenize(playerSpec)
--   playerRealm = 'server=' .. Tokenize(playerRealm)
--   playerRegion = 'region=' .. Tokenize(playerRegion)

--   -- Build the output string for the player (not including gear)
--   local simcPrintError = nil
--   local P1CompanionProfile = ''

--   P1CompanionProfile = P1CompanionProfile .. headerComment .. '\n'
--   P1CompanionProfile = P1CompanionProfile .. versionComment .. '\n'
--   P1CompanionProfile = P1CompanionProfile .. wowVersionComment .. '\n'
--   P1CompanionProfile = P1CompanionProfile .. simcVersionWarning .. '\n'
--   P1CompanionProfile = P1CompanionProfile .. '\n'

--   P1CompanionProfile = P1CompanionProfile .. player .. '\n'
--   P1CompanionProfile = P1CompanionProfile .. playerLevel .. '\n'
--   P1CompanionProfile = P1CompanionProfile .. playerRace .. '\n'
--   if isZandalariTroll then
--     local zandalari_loa = P1Companion:GetZandalariLoa()
--     if zandalari_loa then
--       P1CompanionProfile = P1CompanionProfile .. "zandalari_loa=" .. zandalari_loa .. '\n'
--     end
--   end
--   P1CompanionProfile = P1CompanionProfile .. playerRegion .. '\n'
--   P1CompanionProfile = P1CompanionProfile .. playerRealm .. '\n'
--   P1CompanionProfile = P1CompanionProfile .. playerRole .. '\n'
--   P1CompanionProfile = P1CompanionProfile .. playerProfessions .. '\n'
--   P1CompanionProfile = P1CompanionProfile .. playerSpecStr .. '\n'
--   P1CompanionProfile = P1CompanionProfile .. '\n'

--   if playerSpec == 'unknown' then -- luacheck: ignore
--     -- do nothing
--     -- Player does not have a spec / is in starting player area
--   elseif ClassTalents then
--     -- DRAGONFLIGHT
--     -- new dragonflight talents
--     if Traits.GetLoadoutSerializationVersion() ~= SUPPORTED_LOADOUT_SERIALIZATION_VERSION then
--       simcPrintError = 'This version of the SimC addon does not work with this version of WoW.\n'
--       simcPrintError = simcPrintError .. 'There is a mismatch in the version of talent string exports.\n'
--       simcPrintError = simcPrintError .. '\n'
--       if Traits.GetLoadoutSerializationVersion() > SUPPORTED_LOADOUT_SERIALIZATION_VERSION then
--         simcPrintError = simcPrintError .. 'WoW is using a newer version - you probably need to update your addon.\n'
--       else
--         simcPrintError = simcPrintError .. 'WoW is using an older version - you may be running an alpha/beta addon that is not currently ready for retail.\n'
--       end
--       simcPrintError = simcPrintError .. '\n'
--       simcPrintError = simcPrintError .. 'WoW talent string export version = ' .. Traits.GetLoadoutSerializationVersion() .. '\n'
--       simcPrintError = simcPrintError .. 'Addon talent string export version = ' .. SUPPORTED_LOADOUT_SERIALIZATION_VERSION .. '\n'
--     end

--     local currentConfigId = ClassTalents.GetActiveConfigID()

--     P1CompanionProfile = P1CompanionProfile .. GetExportString(currentConfigId) .. '\n'
--     P1CompanionProfile = P1CompanionProfile .. '\n'

--     local specConfigs = ClassTalents.GetConfigIDsBySpecID(globalSpecID)

--     for _, configId in pairs(specConfigs) do
--       P1CompanionProfile = P1CompanionProfile .. GetExportString(configId) .. '\n'
--     end
--   else
--     -- old talents
--     local playerTalents = CreateSimcTalentString()
--     P1CompanionProfile = P1CompanionProfile .. playerTalents .. '\n'
--   end

--   P1CompanionProfile = P1CompanionProfile .. '\n'

--   -- Method that gets gear information
--   local items = P1Companion:GetItemStrings(debugOutput)

--   -- output gear
--   for slotNum=1, #slotNames do
--     local item = items[slotNum]
--     if item then
--       if item.name then
--         P1CompanionProfile = P1CompanionProfile .. '# ' .. item.name .. '\n'
--       end
--       P1CompanionProfile = P1CompanionProfile .. items[slotNum].string .. '\n'
--     end
--   end

--   -- output gear from bags
--   if noBags == false then
--     local bagItems = P1Companion:GetBagItemStrings(debugOutput)

--     if #bagItems > 0 then
--       P1CompanionProfile = P1CompanionProfile .. '\n'
--       P1CompanionProfile = P1CompanionProfile .. '### Gear from Bags\n'
--       for i=1, #bagItems do
--         P1CompanionProfile = P1CompanionProfile .. '#\n'
--         if bagItems[i].name and bagItems[i].name ~= '' then
--           P1CompanionProfile = P1CompanionProfile .. '# ' .. bagItems[i].name .. '\n'
--         end
--         P1CompanionProfile = P1CompanionProfile .. '# ' .. bagItems[i].string .. '\n'
--       end
--     end
--   end

--   -- output weekly reward gear
--   if WeeklyRewards then
--     if WeeklyRewards:HasAvailableRewards() then
--       P1CompanionProfile = P1CompanionProfile .. '\n'
--       P1CompanionProfile = P1CompanionProfile .. '### Weekly Reward Choices\n'
--       local activities = WeeklyRewards.GetActivities()
--       for _, activityInfo in ipairs(activities) do
--         for _, rewardInfo in ipairs(activityInfo.rewards) do
--           local _, _, _, itemEquipLoc = GetItemInfoInstant(rewardInfo.id)
--           local itemLink = WeeklyRewards.GetItemHyperlink(rewardInfo.itemDBID)
--           local itemName = GetItemName(itemLink);
--           local slotNum = P1Companion.invTypeToSlotNum[itemEquipLoc]
--           if slotNum then
--             local itemStr = GetItemStringFromItemLink(slotNum, itemLink, debugOutput)
--             local level, _, _ = GetDetailedItemLevelInfo(itemLink)
--             P1CompanionProfile = P1CompanionProfile .. '#\n'
--             if itemName and level then
--               itemNameComment = itemName .. ' ' .. '(' .. level .. ')'
--               P1CompanionProfile = P1CompanionProfile .. '# ' .. itemNameComment .. '\n'
--             end
--             P1CompanionProfile = P1CompanionProfile .. '# ' .. itemStr .. "\n"
--           end
--         end
--       end
--       P1CompanionProfile = P1CompanionProfile .. '#\n'
--       P1CompanionProfile = P1CompanionProfile .. '### End of Weekly Reward Choices\n'
--     end
--   end

--   -- Dump out equippable items from a vendor, this is mostly for debugging / data collection
--   local numMerchantItems = GetMerchantNumItems()
--   if showMerchant and numMerchantItems > 0 then
--     P1CompanionProfile = P1CompanionProfile .. '\n'
--     P1CompanionProfile = P1CompanionProfile .. '\n### Merchant items\n'
--     for i=1,numMerchantItems do
--       local link = GetMerchantItemLink(i)
--       local name,_,_,_,_,_,_,_,invType = GetItemInfo(link)
--       if name and invType ~= "" then
--         local slotNum = P1Companion.invTypeToSlotNum[invType]
--         -- Doesn't work, seems to always return base item level
--         -- local level, _, _ = GetDetailedItemLevelInfo(itemLink)
--         local itemStr = GetItemStringFromItemLink(slotNum, link, false)
--         P1CompanionProfile = P1CompanionProfile .. '#\n'
--         if name then
--           P1CompanionProfile = P1CompanionProfile .. '# ' .. name .. '\n'
--         end
--         P1CompanionProfile = P1CompanionProfile .. '# ' .. itemStr .. "\n"
--       end
--     end
--   end


--   -- output item links that were included in the /simc chat line
--   if links and #links > 0 then
--     P1CompanionProfile = P1CompanionProfile .. '\n'
--     P1CompanionProfile = P1CompanionProfile .. '\n### Linked gear\n'
--     for _, v in pairs(links) do
--       local name,_,_,_,_,_,_,_,invType = GetItemInfo(v)
--       if name and invType ~= "" then
--         local slotNum = P1Companion.invTypeToSlotNum[invType]
--         local itemStr = GetItemStringFromItemLink(slotNum, v, debugOutput)
--         P1CompanionProfile = P1CompanionProfile .. '#\n'
--         P1CompanionProfile = P1CompanionProfile .. '# ' .. name .. '\n'
--         P1CompanionProfile = P1CompanionProfile .. '# ' .. itemStr .. "\n"
--       else -- Someone linked something that was not gear.
--         simcPrintError = "Error: " .. v .. " is not gear."
--         break
--       end
--     end
--   end

--   P1CompanionProfile = P1CompanionProfile .. '\n'
--   P1CompanionProfile = P1CompanionProfile .. '### Additional Character Info\n'

--   local upgradeCurrenciesStr = P1Companion:GetUpgradeCurrencies()
--   P1CompanionProfile = P1CompanionProfile .. '#\n'
--   P1CompanionProfile = P1CompanionProfile .. '# upgrade_currencies=' .. upgradeCurrenciesStr .. '\n'

--   local highWatermarksStr = P1Companion:GetSlotHighWatermarks()
--   if highWatermarksStr then
--     P1CompanionProfile = P1CompanionProfile .. '#\n'
--     P1CompanionProfile = P1CompanionProfile .. '# slot_high_watermarks=' .. highWatermarksStr .. '\n'
--   end

--   local upgradeAchievementsStr = P1Companion:GetItemUpgradeAchievements()
--   P1CompanionProfile = P1CompanionProfile .. '#\n'
--   P1CompanionProfile = P1CompanionProfile .. '# upgrade_achievements=' .. upgradeAchievementsStr .. '\n'

--   -- sanity checks - if there's anything that makes the output completely invalid, punt!
--   if specId==nil then
--     simcPrintError = "Error: You need to pick a spec!"
--   end

--   P1CompanionProfile = P1CompanionProfile .. '\n'

--   -- Simple checksum to provide a lightweight verification that the input hasn't been edited/modified
--   local checksum = adler32(P1CompanionProfile)

--   P1CompanionProfile = P1CompanionProfile .. '# Checksum: ' .. string.format('%x', checksum)

--   return P1CompanionProfile, simcPrintError
-- end

-- This is the workhorse function that constructs the profile
function P1Companion:PrintSimcProfile(limit)
  local result = ""
  local count = 0
  local total = #VMRT.LootHistory.list
  
  -- If no limit specified, show all items ending with #0
  limit = limit or total
  
  -- Start from the most recent item and count down
  for i = total, 1, -1 do
    local entry = VMRT.LootHistory.list[i]
    -- Check if the entry ends with #0
    if entry:match("#0$") then
      result = result .. entry .. "\n"
      count = count + 1
      if count >= limit then
        break
      end
    end
  end

  local f = P1Companion:GetMainFrame(result)
  f:Show()
end