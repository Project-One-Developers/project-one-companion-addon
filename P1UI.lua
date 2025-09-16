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
    local restrict_to_char_label = DF:CreateLabel(parent, "Restrict to", 9.5, "white")
    restrict_to_char_label:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -100)

    local restrict_to_char_entry = DF:CreateTextEntry(parent, function(_, _, _) end, 250, 18)
    restrict_to_char_entry:SetTemplate(options_button_template)
    restrict_to_char_entry:SetPoint("LEFT", restrict_to_char_label, "RIGHT", 5, 0)
    restrict_to_char_entry:SetHook("OnEditFocusGained", function(self)
        restrict_to_char_entry.CharacterAutoCompleteList = POC.POUI.AutoComplete["Character"] or {}
        restrict_to_char_entry:SetAsAutoComplete("CharacterAutoCompleteList", _, true)
    end)

    local info_check_button = DF:CreateButton(parent, function()
    end, 120, 18, "Get Info")
    info_check_button:SetTemplate(options_button_template)
    info_check_button:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -30, -100)
    info_check_button:SetHook("OnShow", function(self)
        if (UnitIsGroupLeader("player") or UnitIsGroupAssistant("player") or POC.Settings["Debug"]) then
            self:Enable()
        else
            self:Disable()
        end
    end)

    local character_name_header = DF:CreateLabel(parent, "Character Name", 11)
    character_name_header:SetPoint("TOPLEFT", restrict_to_char_label, "BOTTOMLEFT", 10, -20)

    local simc_header = DF:CreateLabel(parent, "Simc String", 11)
    simc_header:SetPoint("LEFT", character_name_header, "RIGHT", 120, 0)

    local weeklychest_header = DF:CreateLabel(parent, "Weekly Chest", 11)
    weeklychest_header:SetPoint("LEFT", simc_header, "RIGHT", 90, 0)

    local createLootSquare = function(parent, lootIndex, itemLink)
        local lootSquare = CreateFrame("frame", parent:GetName() .. "LootSquare" .. lootIndex, parent)
        lootSquare:SetSize(20, 20)
        lootSquare:SetFrameLevel(parent:GetFrameLevel()+10)
        --lootSquare:Hide()

        lootSquare:SetScript("OnEnter", function(self)
            if (itemLink) then
                GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
                GameTooltip:SetHyperlink(itemLink)
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

        -- local shadowTexture = playerBanner:CreateTexture("$parentShadowTexture", "artwork")
        -- shadowTexture:SetTexture([[Interface\AddOns\Details\images\end_of_mplus_banner_mask.png]])
        -- shadowTexture:SetTexCoord(441/512, 511/512, 81/512, 151/512)
        -- shadowTexture:SetSize(32, 32)
        -- shadowTexture:SetVertexColor(0.05, 0.05, 0.05, 0.6)
        -- shadowTexture:SetPoint("center", lootSquare, "center", 0, 0)
        -- lootSquare.ShadowTexture = shadowTexture

        local lootIcon = lootSquare:CreateTexture("$parentLootIcon", "artwork")
        lootIcon:SetSize(20, 20)
        lootIcon:SetPoint("center", lootSquare, "center", 0, 0)
        lootIcon:SetTexture([[Interface\ICONS\INV_Misc_QuestionMark]])
        lootSquare.LootIcon = lootIcon

        local lootIconBorder = lootSquare:CreateTexture("$parentLootSquareBorder", "overlay")
        lootIconBorder:SetTexture([[Interface\COMMON\BlackIconFrame]])
        lootIconBorder:SetTexCoord(0, 1, 0, 1)
        lootIconBorder:SetSize(20, 20)
        lootIconBorder:SetPoint("center", lootIcon, "center", 0, 0)
        lootSquare.LootIconBorder = lootIconBorder

        -- local lootItemLevel = lootSquare:CreateFontString("$parentLootItemLevel", "overlay", "GameFontNormal")
        -- lootItemLevel:SetPoint("bottom", lootSquare, "bottom", 0, -4)
        -- lootItemLevel:SetTextColor(1, 1, 1)
        -- --detailsFramework:SetFontSize(lootItemLevel, 11)
        -- lootSquare.LootItemLevel = lootItemLevel

        -- local lootItemLevelBackgroundTexture = lootSquare:CreateTexture("$parentItemLevelBackgroundTexture", "artwork", nil, 6)
        -- lootItemLevelBackgroundTexture:SetTexture([[Interface\Cooldown\LoC-ShadowBG]])
        -- lootItemLevelBackgroundTexture:SetPoint("bottomleft", lootSquare, "bottomleft", -7, -3)
        -- lootItemLevelBackgroundTexture:SetPoint("bottomright", lootSquare, "bottomright", 7, -15)
        -- lootItemLevelBackgroundTexture:SetHeight(10)
        -- lootSquare.LootItemLevelBackgroundTexture = lootItemLevelBackgroundTexture

        return lootSquare
    end

    local function refresh(self, data, offset, totalLines)
        for i = 1, totalLines do
            local index = i + offset
            local thisData = data[index] -- thisData = {{name = "Ravxd", version = 1.0, duplicate = true}}
            if thisData then
                local line = self:GetLine(i)

                local name = thisData.name
                local version = thisData.version
                local duplicate = thisData.duplicate
                local nickname = POAPI:Shorten(name)

                line.name:SetText(nickname)
                line.version:SetText(version)
                line.duplicates:SetText(duplicate and "Yes" or "No")

                -- version number color                
                if version and version == "Offline" then
                    line.version:SetTextColor(0.5, 0.5, 0.5, 1)
                elseif version and data[1] and data[1].version and version == data[1].version then
                    line.version:SetTextColor(0, 1, 0, 1)
                else
                    line.version:SetTextColor(1, 0, 0, 1)
                end

                -- duplicates color
                if duplicate then
                    line.duplicates:SetTextColor(1, 0, 0, 1)
                else
                    line.duplicates:SetTextColor(0, 1, 0, 1)
                end
                
                line:SetScript("OnClick", function(self)
                    local message = ""
                    local now = GetTime()
                    if (POI.VersionCheckData.lastclick[name] and now < POI.VersionCheckData.lastclick[name] + 5) or (thisData.version == POI.VersionCheckData.version and not thisData.duplicate) or thisData.version == "No Response" then return end                    
                    POI.VersionCheckData.lastclick[name] = now
                    if POI.VersionCheckData.type == "WA" then
                        local url = POI.VersionCheckData.url ~= "" and POI.VersionCheckData.url or POI.VersionCheckData.name
                        if thisData.version == "WA Missing" then message = "Please install the WeakAura: "..url
                        elseif thisData.version ~= POI.VersionCheckData.version then message = "Please update your WeakAura: "..url end
                        if thisData.duplicate then
                            if message == "" then 
                                message = "Please delete the duplicate WeakAura of: '"..POI.VersionCheckData.name.."'"
                            else 
                                message = message.." Please also delete the duplicate WeakAura"
                            end
                        end
                    elseif POI.VersionCheckData.type == "Addon" then
                        if thisData.version == "Addon not enabled" then message = "Please enable the Addon: '"..POI.VersionCheckData.name.."'"
                        elseif thisData.version == "Addon Missing" then message = "Please install the Addon: '"..POI.VersionCheckData.name.."'"
                        else message = "Please update the Addon: '"..POI.VersionCheckData.name.."'" end
                    elseif POI.VersionCheckData.type == "Note" then 
                        if thisData.version == "MRT not enabled" then message = "Please enable MRT"
                        elseif thisData.version == "MRT not installed" then message = "Please install MRT"
                        else return end
                    end
                    POI.VersionCheckData.lastclick[name] = GetTime()
                    SendChatMessage(message, "WHISPER", nil, name)
                end)
            end
        end
    end

    local textEntryOnFocusGained = function(self)
        self:HighlightText()
    end
        
    local textEntryOnFocusLost = function(self)
        self:HighlightText (0, 0)
    end

    local function createLineFunc(self, index)
        local line = CreateFrame("button", "$parentLine" .. index, self, "BackdropTemplate")
        line:SetPoint("TOPLEFT", self, "TOPLEFT", 1, -((index-1) * (self.LineHeight+1)) - 1)
        line:SetSize(self:GetWidth() - 2, self.LineHeight)
        DF:ApplyStandardBackdrop(line)
        DF:CreateHighlightTexture(line)
        line.index = index

        local name = DF:CreateLabel(line, "", "white")
        name:SetWidth(100)
        name:SetJustifyH("LEFT")
        name:SetFont(expressway, 12, "OUTLINE")
        name:SetPoint("LEFT", line, "LEFT", 5, 0)
        line.name = name

        local simc = DF:CreateTextEntry(line, function() end, 165, 20)
        simc:SetJustifyH("LEFT")
        simc:SetFont(expressway, 12, "OUTLINE")
        simc:SetPoint("LEFT", name, "RIGHT", 110, 0)
        simc:SetTemplate(options_dropdown_template)
        simc:SetHook("OnEditFocusGained", textEntryOnFocusGained)
        simc:SetHook("OnEditFocusLost", textEntryOnFocusLost)
        line.version = simc

        local weeklyChest = DF:CreateLabel(line, "", "white")
        weeklyChest:SetWidth(20)
        weeklyChest:SetJustifyH("LEFT")
        weeklyChest:SetFont(expressway, 12, "OUTLINE")
        weeklyChest:SetPoint("LEFT", simc, "RIGHT", 10, 0)
        line.duplicates = weeklyChest
        
        local weeklyItems = DF:CreateLabel(line, "", "white")
        weeklyItems:SetWidth(100)
        weeklyItems:SetJustifyH("LEFT")
        weeklyItems:SetFont(expressway, 12, "OUTLINE")
        weeklyItems:SetPoint("LEFT", weeklyChest, "RIGHT", 10, 0)
        line.test = weeklyItems

        POI:Print("weeklyItems", weeklyItems)

        -- loot items for testing
        line.LootSquares = {}
        for i = 1, 1 do
            local lootSquare = createLootSquare(line, i, "|cff0070dd|Hitem:63470::::::::53:257::2:1:4198:2:28:1199:9:35:::::|h[Missing Diplomat's Pauldrons]|h|r")
            if (i == 1) then
                lootSquare:SetPoint("RIGHT", weeklyItems.widget, "LEFT", 30, 0)
            else
                lootSquare:SetPoint("RIGHT", line.LootSquares[i-1], "LEFT", -2, 0)
            end

            -- debug only
            -- local lootInfo = lootCandidates[i]
            -- local itemLink = lootInfo.itemLink
            -- local effectiveILvl = lootInfo.effectiveILvl
            -- local itemQuality = lootInfo.itemQuality
            -- local itemID = lootInfo.itemID
            --lootSquare.itemLink = itemLink --will error if this the thrid lootSquare (creates only 2 per banner)
            lootSquare.LootIcon:SetTexture(C_Item.GetItemIconByID(63470))
            --local rarityColor = --[[GLOBAL]] ITEM_QUALITY_COLORS[itemQuality]
            --lootSquare.LootIconBorder:SetVertexColor(rarityColor.r, rarityColor.g, rarityColor.b, 1)
            --lootSquare.LootItemLevel:SetText(effectiveILvl or "0")

            --lootSquare:Show()

            line.LootSquares[i] = lootSquare
            line["lootSquare" .. i] = lootSquare
        end
        -- local lootsquare = createLootSquare(line, "|cff0070dd|Hitem:63470::::::::53:257::2:1:4198:2:28:1199:9:35:::::|h[Missing Diplomat's Pauldrons]|h|r")
        -- lootsquare:SetPoint("right", weeklyItems, "RIGHT", 10, 0)

        -- local weeklyChest = line:CreateFontString(nil, "OVERLAY")
        -- weeklyChest:SetWidth(100)
        -- weeklyChest:SetJustifyH("LEFT")
        -- weeklyChest:SetFont(expressway, 12, "OUTLINE")
        -- weeklyChest:SetPoint("LEFT", line, "RIGHT", 130, 0)
        -- line.duplicates = weeklyChest

        return line
    end

    local scrollLines = 19

    local version_check_scrollbox = DF:CreateScrollBox(parent, "VersionCheckScrollBox", refresh, {},
        window_width - 40,
        window_height - 180, scrollLines, 20, createLineFunc)
    DF:ReskinSlider(version_check_scrollbox)
    version_check_scrollbox.ReajustNumFrames = true
    version_check_scrollbox:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -150)
    for i = 1, scrollLines do
        version_check_scrollbox:CreateLine(createLineFunc)
    end
    version_check_scrollbox:Refresh()

    version_check_scrollbox.name_map = {} -- name is the key
    
    -- invoke to add data when receive msg back from players
    local addData = function(self, data, url)
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

    version_check_scrollbox.AddData = addData
    version_check_scrollbox.WipeData = wipeData

    info_check_button:SetScript("OnClick", function(self)
        
        local charName = restrict_to_char_entry:GetText()
        local component_type = "Simc" -- no other checks available in this ui tab
        
        -- fill autocomplete list if needed
        if charName and charName ~= ""  and not tContains(POC.POUI.AutoComplete["Character"], charName) then
            tinsert(POC.POUI.AutoComplete["Character"], charName)
        end
        
        local now = GetTime()
        if POI.LastVersionCheck and POI.LastVersionCheck > now-2 then return end -- don't let user spam requests
        POI.LastVersionCheck = now
        version_check_scrollbox:WipeData()
        local userData, url = POI:RequestVersionNumber(component_type, charName)
        if userData then
            POI.VersionCheckData = { version = userData.version, type = component_type, name = charName, url = url, lastclick = {} }
            version_check_scrollbox:AddData(userData, url)
        end
    end)

    return version_check_scrollbox
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

function POAPI:DisplayText(text, duration)
    if POUI and POUI.generic_display then
        POUI.generic_display.text:SetText(text)
        POUI.generic_display:Show()
        C_Timer.After(duration or 4, function() POUI.generic_display:Hide() end)
    end
end

POI.POUI = POUI