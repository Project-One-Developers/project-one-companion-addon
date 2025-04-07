-- Ignore some luacheck warnings about global vars, just use a ton of them in WoW Lua
-- luacheck: no global
-- luacheck: no self
local _, P1Companion = ...

P1Companion = LibStub("AceAddon-3.0"):NewAddon(P1Companion, "P1Companion", "AceConsole-3.0", "AceEvent-3.0")

LibDBIcon = LibStub("LibDBIcon-1.0")

local P1Frame = nil
local OptionsDB = nil

-- Set up DataBroker for minimap button
P1LDB = LibStub("LibDataBroker-1.1"):NewDataObject("P1Companion", {
  type = "data source",
  text = "P1Companion",
  label = "P1Companion",
  icon = "Interface\\AddOns\\P1Companion\\logo",
  OnClick = function()
    if P1Frame and P1Frame:IsShown() then
      P1Frame:Hide()
    else
      P1Companion:PrintLootHistory()
    end
  end,
  OnTooltipShow = function(tt)
    tt:AddLine("P1 Companion")
    tt:AddLine(" ")
    tt:AddLine("Click to show loots")
    tt:AddLine("To toggle minimap button, type '/P1 minimap'")
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
  LibDBIcon:Register("P1Companion", P1LDB, OptionsDB.profile.minimap)
  P1Companion:UpdateMinimapButton()
  P1Companion:RegisterChatCommand('p1', 'HandleChatCommand')
  AddonCompartmentFrame:RegisterAddon({
    text = "P1Companion",
    icon = "Interface\\AddOns\\P1Companion\\logo",
    notCheckable = true,
    func = function()
      P1Companion:PrintLootHistory()
    end,
  })
end

function P1Companion:OnEnable()

end

function P1Companion:OnDisable()

end

local function CreateNumberInputPopup()
  local f = CreateFrame("Frame", "P1CompanionNumberInput", UIParent, "DialogBoxFrame")
  f:SetSize(250, 125)
  f:SetPoint("CENTER")
  f:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\PVPFrame\\UI-Character-PVP-Highlight",
    edgeSize = 16,
    insets = { left = 8, right = 8, top = 8, bottom = 8 },
  })
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  
  -- Title text
  local title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  title:SetPoint("TOP", 0, -10)
  title:SetText("Enter number of items to show")
  
  -- Create editbox
  local editbox = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
  editbox:SetSize(100, 20)
  editbox:SetPoint("CENTER", 0, 10)
  editbox:SetAutoFocus(false)
  editbox:SetNumeric(true)
  
  -- Store references
  f.editbox = editbox
  
  -- Get the button that DialogBoxFrame creates
  local okayButton = f:GetChildren()
  
  -- Set up the button click handler
  okayButton:SetScript("OnClick", function()
    local number = tonumber(editbox:GetText())
    if number and number > 0 then
      P1Companion:PrintLootHistory(number)
      f:Hide()
      editbox:SetText("")
    end
  end)
  
  -- Set up enter key press handler
  editbox:SetScript("OnEnterPressed", function()
    okayButton:Click()
  end)
  
  -- Set up escape key handler
  editbox:SetScript("OnEscapePressed", function()
    f:Hide()
    editbox:SetText("")
  end)
  
  f:Hide()
  return f
end


function P1Companion:HandleChatCommand(input)
  local args = {strsplit(' ', input)}

  for i = 1, #args do
    local arg = args[i]
    if arg == 'loot' then
      -- Check if there's a number argument after 'loot'
      local nextArg = args[i + 1]
      local number = nextArg and tonumber(nextArg)
      
      if number and number > 0 then
        -- If a valid number was provided, show results directly
        self:PrintLootHistory(number)
      else
        -- If no number or invalid number, show the input popup
        if not P1CompanionNumberInput then
          CreateNumberInputPopup()
        end
        P1CompanionNumberInput:Show()
        P1CompanionNumberInput.editbox:SetFocus()
      end
      return
    elseif arg == 'comp' then
      self:PrintComp()
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
  if not P1Frame then
    -- Main Frame
    local frameConfig = OptionsDB.profile.frame
    local f = CreateFrame("Frame", "P1Frame", UIParent, "DialogBoxFrame")
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
    local sf = CreateFrame("ScrollFrame", "P1ScrollFrame", f, "UIPanelScrollFrameTemplate")
    sf:SetPoint("LEFT", 16, 0)
    sf:SetPoint("RIGHT", -32, 0)
    sf:SetPoint("TOP", 0, -32)
    sf:SetPoint("BOTTOM", P1FrameButton, "TOP", 0, 0)

    -- edit box
    local ctrlDown = false
    local eb = CreateFrame("EditBox", "P1EditBox", P1ScrollFrame)
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
    local rb = CreateFrame("Button", "P1ResizeButton", f)
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

    P1Frame = f
  end
  P1EditBox:SetText(text)
  P1EditBox:HighlightText()
  return P1Frame
end


-- This is the workhorse function that constructs the profile
function P1Companion:PrintLootHistory(limit)
  local result = ""
  local count = 0
  local total = #VMRT.LootHistory.list
  
  -- If no limit specified, show all items ending with #0
  limit = limit or total
  
  -- Start from the most recent item and count down
  for i = total, 1, -1 do
    local entry = VMRT.LootHistory.list[i]

    result = result .. entry .. "\n"
    count = count + 1
    if count >= limit then
      break
    end
  end

  local f = P1Companion:GetMainFrame(result)
  f:Show()
end

function P1Companion:PrintComp()
  local result = ""
  local diff = GetRaidDifficultyID() -- 16 Mythic

   -- in case of normal/hc we take group 1-6
  local upperGroup = 6
  if diff == 16 then
    -- in case of mythic we take group 1-4
    upperGroup = 4
  end

  for i = 1, 40 do
      local name,_,subgroup = GetRaidRosterInfo(i)
      if name and subgroup > 0 and subgroup <= upperGroup  then
        result = result .. name .. "\n"
      end
  end

  local f = P1Companion:GetMainFrame(result)
  f:Show()
end