local _, POI = ... -- Internal namespace
local DF = _G["DetailsFramework"]
local LDB = LibStub("LibDataBroker-1.1")
local LDBIcon = LDB and LibStub("LibDBIcon-1.0")
local WA = _G["WeakAuras"]

local window_width = 900
local window_height = 515
local expressway = [[Interface\AddOns\P1Companion\Media\Fonts\Expressway.TTF]]

local TABS_LIST = {
    { name = "General",   text = "General" },
    { name = "Versions",  text = "Simulations" },
    { name = "WeakAuras", text = "WeakAuras(WIP)" },
}
local authorsString = "By Shant"

local options_text_template = DF:GetTemplate("font", "OPTIONS_FONT_TEMPLATE")
local options_dropdown_template = DF:GetTemplate("dropdown", "OPTIONS_DROPDOWN_TEMPLATE")
local options_switch_template = DF:GetTemplate("switch", "OPTIONS_CHECKBOX_TEMPLATE")
local options_slider_template = DF:GetTemplate("slider", "OPTIONS_SLIDER_TEMPLATE")
local options_button_template = DF:GetTemplate("button", "OPTIONS_BUTTON_TEMPLATE")

local POUI_panel_options = {
    UseStatusBar = true
}
local POUI = DF:CreateSimplePanel(UIParent, window_width, window_height, "|cFF00FFFFProject One|r Companion", "POUI", POUI_panel_options)
POUI:SetPoint("CENTER")
POUI:SetFrameStrata("HIGH")

DF:BuildStatusbarAuthorInfo(POUI.StatusBar, _, "x |cFF00FFFFbird|r")
POUI.StatusBar.discordTextEntry:SetText("https://discord.gg/RfhtBRR3yW")

POUI.OptionsChanged = {
    ["general"] = {},
    ["versions"] = {},
    ["weakauras"] = {},
}

-- version check ui
local function BuildVersionCheckUI(parent)
    
    local restrictToCharLabel = DF:CreateLabel(parent, "Restrict to", 9.5, "white")
    restrictToCharLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -100)

    local restrictToCharEntry = DF:CreateTextEntry(parent, function()end, 150, 18, nil, nil, nil, options_dropdown_template)
    restrictToCharEntry.tooltip = "Enter the player name to restrict the info check"
    restrictToCharEntry:SetPoint("LEFT", restrictToCharLabel, "RIGHT", 5, 0)
    restrictToCharEntry.CharacterAutoCompleteList = POI:GetOnlineGuildNames()
    restrictToCharEntry:SetAsAutoComplete("CharacterAutoCompleteList")

    local infoCheckButton = DF:CreateButton(parent, function()end, 120, 18, "Get Info")
    infoCheckButton:SetTemplate(options_button_template)
    infoCheckButton:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -30, -100)
    infoCheckButton:SetHook("OnShow", function(self)
        if (UnitIsGroupLeader("player") or UnitIsGroupAssistant("player") or POC.Settings["Debug"]) then
            self:Enable()
        else
            self:Disable()
        end
    end)

    ---@param line scrollframe line
    ---@param name string
    ---@param parent frame
    ---@param index number
    local createIconSquare = function(line, iconName, index)
        local lootSquare = CreateFrame("frame", line:GetName() .. iconName .. index, line)
        lootSquare:SetSize(46, 46)
        lootSquare:SetFrameLevel(line:GetFrameLevel()+10)
        lootSquare:Hide()

        lootSquare:SetScript("OnEnter", function(self)
            if (self.itemLink) then
                GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
                GameTooltip:SetHyperlink(lootSquare.itemLink)
                GameTooltip:Show()

                self:SetScript("OnUpdate", function()
                    if (IsShiftKeyDown()) then
                        GameTooltip_ShowCompareItem()
                    else
                        GameTooltip_HideShoppingTooltips(GameTooltip)
                    end
                end)
            end
        end)

        lootSquare:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
            self:SetScript("OnUpdate", nil)
        end)

        local lootIcon = lootSquare:CreateTexture("$parentLootIcon", "artwork")
        lootIcon:SetSize(46, 46)
        lootIcon:SetPoint("center", lootSquare, "center", 0, 0)
        lootIcon:SetTexture([[Interface\ICONS\INV_Misc_QuestionMark]])
        lootSquare.Icon = lootIcon

        local lootIconBorder = lootSquare:CreateTexture("$parentLootSquareBorder", "overlay")
        lootIconBorder:SetTexture([[Interface\COMMON\WhiteIconFrame]])
        lootIconBorder:SetTexCoord(0, 1, 0, 1)
        lootIconBorder:SetSize(46, 46)
        lootIconBorder:SetPoint("center", lootIcon, "center", 0, 0)
        lootSquare.IconBorder = lootIconBorder

        local lootItemLevel = lootSquare:CreateFontString("$parentLootItemLevel", "overlay", "GameFontNormal")
        lootItemLevel:SetPoint("bottom", lootSquare, "bottom", 0, -4)
        lootItemLevel:SetTextColor(1, 1, 1)
        DF:SetFontSize(lootItemLevel, 11)
        lootSquare.ItemLevel = lootItemLevel

        local lootItemLevelBackgroundTexture = lootSquare:CreateTexture("$parentItemLevelBackgroundTexture", "artwork", nil, 6)
        lootItemLevelBackgroundTexture:SetTexture([[Interface\Cooldown\LoC-ShadowBG]])
        lootItemLevelBackgroundTexture:SetPoint("bottomleft", lootSquare, "bottomleft", -7, -3)
        lootItemLevelBackgroundTexture:SetPoint("bottomright", lootSquare, "bottomright", 7, -15)
        lootItemLevelBackgroundTexture:SetHeight(10)
        lootSquare.ItemLevelBackgroundTexture = lootItemLevelBackgroundTexture

        return lootSquare
    end

    local function refresh(self, data, offset, totalLines)
        for i = 1, totalLines do
            local index = i + offset
            local thisData = data[index] -- thisData = {{name = "Ravxd", simc = "Mega Simc String", vault = {weeklyreward-table}, currencies = {currencies-table} }}
            if thisData then
                local line = self:GetLine(i)
                POI:Print("refresh", line, index, data, offset, totalLines, thisData and thisData.name or "nil")
                local name = thisData.name
                local simc = thisData.simc
                local weeklyRewards = thisData.vault
                local currencies = thisData.currencies
                local nickname = POAPI:Shorten(name)

                line.Name:SetText(nickname)
                line.Simc:SetText(simc)
                --line.Currencies:SetText(currencies or "Not available")
                line.WeeklyRewards:SetText(weeklyRewards or "Not available")

                if (type(currencies) == "table") then
                    POI:Print("currencies", currencies)
                    for currencyId, currencyInfo in pairs(currencies) do
                        local iconSquare = line["currencySquare" .. currencyId]
                        if iconSquare then
                            local quantity = currencyInfo.quantity or 0
                            iconSquare.Icon:SetTexture(currencyInfo.iconFileID)
                            --iconSquare.ItemLevel:SetText(quantity.."/"..currencyInfo.maxQuantity)
                            iconSquare.ItemLevel:SetText(quantity)
                            iconSquare.itemLink = currencyInfo.itemLink
                            iconSquare:Show()
                        end
                    end
                end

                -- local lootInfo = lootCandidates[i]
                -- local itemLink = lootInfo.itemLink
                -- local effectiveILvl = lootInfo.effectiveILvl
                -- local itemQuality = lootInfo.itemQuality
                -- local itemID = lootInfo.itemID

                -- local lootSquare = playerBanner:GetLootSquare() --internally controls the loot square index
                -- lootSquare.itemLink = itemLink --will error if this the thrid lootSquare (creates only 2 per banner)

                -- local rarityColor = --[[GLOBAL]] ITEM_QUALITY_COLORS[itemQuality]
                -- lootSquare.LootIcon:SetTexture(C_Item.GetItemIconByID(itemID))
                -- lootSquare.LootIconBorder:SetVertexColor(rarityColor.r, rarityColor.g, rarityColor.b, 1)
                -- lootSquare.LootItemLevel:SetText(effectiveILvl or "0")

                -- --update size
                -- lootSquare.LootIcon:SetSize(playerBannerSettings.loot_square_width, playerBannerSettings.loot_square_height)
                -- lootSquare.LootIconBorder:SetSize(playerBannerSettings.loot_square_width, playerBannerSettings.loot_square_height)

                -- lootSquare:Show()

                -- version number color                
                if simc and simc == "Offline" then
                    line.Simc:SetTextColor(0.5, 0.5, 0.5, 1)
                else
                    line.Simc:SetTextColor(1, 0, 0, 1)
                end

                -- currencies color
                -- if currencies then
                --     line.Currencies:SetTextColor(1, 0, 0, 1)
                -- else
                --     line.Currencies:SetTextColor(0, 1, 0, 1)
                -- end
            end
        end
    end

    local function createLineFunc(self, index)
        local line = CreateFrame("frame", "$parentLine" .. index, self, "BackdropTemplate")
        local scrollLineHeight = 20
        line.index = index

        line:SetPoint("topleft", self, "topleft", 2, (scrollLineHeight * (index - 1) * -1) - 2)
        line:SetPoint("topright", self, "topright", -2, (scrollLineHeight * (index - 1) * -1) - 2)
        line:SetHeight(scrollLineHeight)

        DF:Mixin(line, DF.HeaderFunctions)
        DF.BackdropUtil:SetColorStripe(line, index)

        local header = self:GetParent().Header

        -- name
        local name = DF:CreateLabel(line, "")
        name:SetFont(expressway, 12, "OUTLINE")

        -- simc
        local simc = DF:CreateTextEntry(line, function()end, header:GetColumnWidth(2), scrollLineHeight, nil, nil, nil, options_dropdown_template)
        simc:SetJustifyH("left")
        simc:SetTextInsets(3, 3, 0, 0)
        simc:SetText("Test")
        simc:SetAutoSelectTextOnFocus(true)

        -- currencies icons
        line.CurrencySquares = {}
        local currencyIndex = 1
        for currencyId, currencyName in pairs(POI.UpgradeCurrencies) do
            local iconSquare = createIconSquare(line, "CurrencySquare", currencyId)
            iconSquare:SetSize(scrollLineHeight - 2, scrollLineHeight - 2)
            iconSquare.Icon:SetSize(scrollLineHeight - 2, scrollLineHeight - 2)
            iconSquare.IconBorder:SetSize(scrollLineHeight - 2, scrollLineHeight - 2)
            if (currencyIndex > 1) then
                -- first icon is aligned with header, the rest aligned to previous icon
                iconSquare:SetPoint("right", line.CurrencySquares[currencyIndex-1], "right", scrollLineHeight+2, 0)
            end
            line.CurrencySquares[currencyIndex] = iconSquare
            line["currencySquare" .. currencyId] = iconSquare
            currencyIndex = currencyIndex + 1
        end

        -- weeklyrewards icons
        line.LootSquares = {}
        local weeklyRewardsAmount = 9
        for i = 1, weeklyRewardsAmount do
            local lootSquare = createIconSquare(line, "WeeklyRewardSquare", i)
            if (i > 1) then
                -- first icon is aligned with header, the rest aligned to previous icon
                lootSquare:SetPoint("right", line.CurrencySquares[currencyIndex-1], "right", scrollLineHeight+2, 0)
            end
            line.LootSquares[i] = lootSquare
            line["lootSquare" .. i] = lootSquare
        end

        function line:ClearLootSquares()
            line.NextLootSquare = 1
            for _, lootSquare in ipairs(self.LootSquares) do
                lootSquare:Hide()
                lootSquare.itemLink = nil
                lootSquare.LootIcon:SetTexture([[Interface\ICONS\INV_Misc_QuestionMark]])
                lootSquare.LootItemLevel:SetText("")
            end
	    end

        function line:GetLootSquare()
            local lootSquareIdx = line.NextLootSquare
            line.NextLootSquare = lootSquareIdx + 1
            local lootSquare = line.LootSquares[lootSquareIdx]
            lootSquare:Show()
            return lootSquare
        end

        -- local currencies = DF:CreateTextEntry(line, function()end, header:GetColumnWidth(3), scrollLineHeight, nil, nil, nil, options_dropdown_template)
        -- currencies:SetJustifyH("left")
        -- currencies:SetTextInsets(3, 3, 0, 0)
        -- currencies:Disable()

        -- weekly reward 
        local weeklyRewards = DF:CreateTextEntry(line, function()end, header:GetColumnWidth(4), scrollLineHeight, nil, nil, nil, options_dropdown_template)
        weeklyRewards:SetJustifyH("left")
        weeklyRewards:SetTextInsets(3, 3, 0, 0)
        weeklyRewards:Disable()

        line:AddFrameToHeaderAlignment(name)
        line:AddFrameToHeaderAlignment(simc)
        line:AddFrameToHeaderAlignment(line.CurrencySquares[1]) -- align the first currency square, the rest will follow
        line:AddFrameToHeaderAlignment(weeklyRewards) -- align the first loot square, the rest will follow

        line:AlignWithHeader(header, "left")

        line.Name = name
        line.Simc = simc
        line.Currencies = currencies
        line.WeeklyRewards = weeklyRewards

        return line
    end

    -- scroll container
    local resultsFrame = CreateFrame("frame", parent:GetName() .. "ResultsFrame", parent)
    resultsFrame:SetPoint("topleft", parent, "topleft", 10, -150)
    resultsFrame:SetSize(window_width - 40, window_height - 180)

    -- scrollbox header
	local headerOptions = {
		padding = 2,
	}

    local headerTable = {
        {text = "Name", width = 100},
        {text = "Simc", width = 150},
        {text = "Currencies", width = 150},
        {text = "Weekly Reward", width = 200}
    }

	---create the header frame, the header frame is the frame which shows the columns names to describe the data shown in the scrollframe
	---@type df_headerframe
    resultsFrame.Header = DF:CreateHeader(resultsFrame, headerTable, headerOptions)
    resultsFrame.Header:SetPoint("topleft", resultsFrame, "topleft", 0, 20)

    -- actual scrollbox
    local defaultAmountOfLines = 25
    local scrollLineHeight = 20
    local resultsScrollbox = DF:CreateScrollBox(resultsFrame, "PlayerInfoScrollBox", refresh, {}, window_width - 40, window_height - 180, defaultAmountOfLines, scrollLineHeight)
    DF:ReskinSlider(resultsScrollbox)
    resultsScrollbox.ReajustNumFrames = true
    resultsScrollbox:SetPoint("TOPLEFT", resultsFrame, "TOPLEFT", 0, 0)
    -- prepare lines
    resultsScrollbox:CreateLines(createLineFunc, defaultAmountOfLines)
    resultsScrollbox:Refresh()

    -- scrollbox utils

    resultsScrollbox.name_map = {} -- name is the key
    
    -- invoke to add data when receive msg back from players
    local addData = function(self, data)
        local currentData = self:GetData() -- currentData = {{name, version, duplicate}...}
        if self.name_map[data.name] then
            currentData[self.name_map[data.name]] = data
        else
            self.name_map[data.name] = #currentData + 1
            tinsert(currentData, data)
        end
        self:Refresh()
    end

    local wipeData = function(self)
        self:SetData({})
        wipe(self.name_map)
        self:Refresh()
    end

    resultsScrollbox.AddData = addData
    resultsScrollbox.WipeData = wipeData

    infoCheckButton:SetScript("OnClick", function(self)
        
        local charName = restrictToCharEntry:GetText()

        -- debug
        charName = UnitName("player")

        local component_type = "Simc" -- no other checks available in this ui tab
        
        local now = GetTime()
        if POI.LastVersionCheck and POI.LastVersionCheck > now-2 then return end -- don't let user spam requests
        POI.LastVersionCheck = now
        resultsScrollbox:WipeData()
       
        -- Ask for data via broadcast event
        POI:RequestPlayersInfo(component_type, charName)
    end)

    return resultsScrollbox
end

function POUI:Init()
    -- Create the scale bar
    DF:CreateScaleBar(POUI, POC.POUI)
    POUI:SetScale(POC.POUI.scale)

    -- Create the tab container
    local tabContainer = DF:CreateTabContainer(POUI, "Project One", "POUI_TabsTemplate", TABS_LIST, {
        width = window_width,
        height = window_height - 5,
        backdrop_color = { 0, 0, 0, 0.2 },
        backdrop_border_color = { 0.1, 0.1, 0.1, 0.4 }
    })
    -- Position the tab container within the main frame
    -- tabContainer:SetPoint("TOP", POUI, "TOP", 0, 0)
    tabContainer:SetPoint("CENTER", POUI, "CENTER", 0, 0)

    local general_tab = tabContainer:GetTabFrameByName("General")
    local versions_tab = tabContainer:GetTabFrameByName("Versions")
    local weakaura_tab = tabContainer:GetTabFrameByName("WeakAuras")

    -- generic text display
    local generic_display = CreateFrame("Frame", "POUIGenericDisplay", UIParent, "BackdropTemplate")
    generic_display:SetPoint("CENTER", UIParent, "CENTER", 0, 350)
    generic_display:SetSize(300, 100)
    generic_display.text = generic_display:CreateFontString(nil, "OVERLAY")
    generic_display.text:SetFont(expressway, 20, "OUTLINE")
    generic_display.text:SetPoint("CENTER", generic_display, "CENTER", 0, 0)
    generic_display:Hide()
    POUI.generic_display = generic_display

    local general_callback = function()
        -- when any setting is changed, call these respective callback function
        wipe(POUI.OptionsChanged["general"])
    end
    local versions_callback = function()
        wipe(POUI.OptionsChanged["versions"])
    end
    local weakauras_callback = function()
        wipe(POUI.OptionsChanged["weakauras"])
    end

    -- options
    local general_options1_table = {
        { type = "label", get = function() return "General Options" end, text_template = DF:GetTemplate("font", "ORANGE_FONT_TEMPLATE") },
        {
            type = "toggle",
            boxfirst = true,
            name = "Disable Minimap Button",
            desc = "Hide the minimap button.",
            get = function() return POC.Settings["Minimap"].hide end,
            set = function(self, fixedparam, value)
                POC.Settings["Minimap"].hide = value                
                LDBIcon:Refresh("POC", POC.Settings["Minimap"])
            end,
        },

        {
            type = "toggle",
            boxfirst = true,
            name = "Enable Debug Logging",
            desc = "Enables Debug Logging, which prints a bunch of information and adds it to DevTool. This might Error if you do not have the DevTool Addon installed.\nIf enabled after a wipe, it will still add External and Macro data to DevTool",
            get = function() return POC.Settings["DebugLogs"] end,
            set = function(self, fixedparam, value)
                POUI.OptionsChanged.general["DEBUGLOGS"] = true
                POC.Settings["DebugLogs"] = value
            end,
        },

        {
            type = "breakline"
        },   

        { type = "label", get = function() return "Meme Images" end,     text_template = DF:GetTemplate("font", "ORANGE_FONT_TEMPLATE") },
        {
            type = "toggle",
            boxfirst = true,
            name = "Break timer",
            desc = "Enable Meme images during break timer",
            get = function() return POC.Settings["MemeBreakTimer"] end,
            set = function(self, fixedparam, value)
                POUI.OptionsChanged.general["MEME_BREAK_TIMER"] = true
                POC.Settings["MemeBreakTimer"] = value
            end,
        },  
    }

    local weakaura_options1_table = {
        {
            type = "label",
            get = function() return "Raid Auras" end,
            text_template = DF:GetTemplate("font", "ORANGE_FONT_TEMPLATE"),
        },
        {
            type = "button",
            name = "Manaforge Raid WA",
            desc = "Import Manaforge Omega WeakAuras",            
            func = function(self)
                --ImportWeakAura("raid_weakaura_manaforge")
            end,
            nocombat = true,
            spacement = true,
        },
        {
            type = "breakline"
        },

        {
            type = "label",
            get = function() return "WeakAura Updates" end,
            text_template = DF:GetTemplate("font", "ORANGE_FONT_TEMPLATE"),
        },

        {
            type = "toggle",
            boxfirst = true,
            name = "Auto Update WA",
            desc = "Automatically update WeakAuras. (Requires WeakAuras Companion Desktop Application)",
            get = function() return POC.Settings["AutoUpdateWA"] end,
            set = function(self, fixedparam, value)
                POC.Settings["AutoUpdateWA"] = value
            end,
        },
        {
            type = "breakline"
        },
    }


    -- Build options menu for each tab
    DF:BuildMenu(general_tab, general_options1_table, 10, -100, window_height - 10, false, options_text_template,
        options_dropdown_template, options_switch_template, true, options_slider_template, options_button_template,
        general_callback)
    DF:BuildMenu(weakaura_tab, weakaura_options1_table, 10, -100, window_height - 10, false, options_text_template,
        options_dropdown_template, options_switch_template, true, options_slider_template, options_button_template,
        weakauras_callback)

    -- Build version check UI
    POUI.version_scrollbox = BuildVersionCheckUI(versions_tab)

    -- Version Number in status bar
    local versionTitle = C_AddOns.GetAddOnMetadata("P1Companion", "Title")
    local versionNumber = C_AddOns.GetAddOnMetadata("P1Companion", "Version")
    local statusBarText = versionTitle .. " v" .. versionNumber .. " | |cFFFFFFFF" .. (authorsString) .. "|r"
    POUI.StatusBar.authorName:SetText(statusBarText)
end

function POUI:ToggleOptions()
    if POUI:IsShown() then
        POUI:Hide()
    else
        POUI:Show()
    end
end

function POI:ExportLootsPopup(amount)
    local popup = DF:CreateSimplePanel(UIParent, 800, 300, "Loot Export", "LootExportPopup", {
        DontRightClickClose = false
    })
    popup:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    popup:SetFrameLevel(100)

    popup.export_loot_text_box = DF:NewSpecialLuaEditorEntry(popup, 280, 80, _, "LootExportTextEdit", true, false, true)
    popup.export_loot_text_box:SetPoint("TOPLEFT", popup, "TOPLEFT", 10, -30)
    popup.export_loot_text_box:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", -30, 40)
    DF:ApplyStandardBackdrop(popup.export_loot_text_box)
    DF:ReskinSlider(popup.export_loot_text_box.scroll)
    popup.export_loot_text_box:SetFocus()
    popup.export_loot_text_box:SetText(POI:GetLootHistoryString(amount))
    getmetatable(popup.export_loot_text_box.editbox).__index.HighlightText(popup.export_loot_text_box.editbox) -- need this bullshit because its not exposed in the API

    return popup
end

function POI:ExportCompPopup()
    local popup = DF:CreateSimplePanel(UIParent, 300, 400, "Comp Export", "CompExportPopup", {
        DontRightClickClose = false
    })
    popup:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    popup:SetFrameLevel(100)

    popup.comp_export_text_box = DF:NewSpecialLuaEditorEntry(popup, 280, 80, _, "CompExportTextEdit", true, false, true)
    popup.comp_export_text_box:SetPoint("TOPLEFT", popup, "TOPLEFT", 10, -30)
    popup.comp_export_text_box:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", -30, 40)
    DF:ApplyStandardBackdrop(popup.comp_export_text_box)
    DF:ReskinSlider(popup.comp_export_text_box.scroll)
    popup.comp_export_text_box:SetFocus()
    popup.comp_export_text_box:SetText(POI:GetCompString())
    getmetatable(popup.comp_export_text_box.editbox).__index.HighlightText(popup.comp_export_text_box.editbox) -- need this bullshit because its not exposed in the API

    return popup
end

function POI:GetOnlineGuildNames()
    if not IsInGuild() then return {} end
    local names = {}
    local numTotalMembers = GetNumGuildMembers()
    for i = 1, numTotalMembers do
        local name, rank, rankIndex, level, class, zone, note, officernote, isOnline = GetGuildRosterInfo(i)
        if name and isOnline and rankIndex <= 5 then
            name = name:gsub("-.*", "") -- remove realm name
            tinsert(names, name)
        end
    end
    return names
end

function POAPI:DisplayText(text, duration)
    if POUI and POUI.generic_display then
        POUI.generic_display.text:SetText(text)
        POUI.generic_display:Show()
        C_Timer.After(duration or 4, function() POUI.generic_display:Hide() end)
    end
end

POI.POUI = POUI