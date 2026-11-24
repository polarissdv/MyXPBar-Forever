local ADDON_NAME, ns = ...
local T = ns.T

-- =========================================================
-- STYLE (native WoW look)
-- =========================================================
local VERSION = ns.AddonVersion()
-- A list of pages on the left, the widgets of the chosen one on the right:
-- the menu holds everything without running past the bottom of a screen.
local PAD = 14
local GUTTER = 12
local CARD_PAD = 12                                    -- Inside a card
local SIDE_W = 150                                     -- The list of pages
local CONTENT_W = 362                                  -- The page beside it
local FULL_W = SIDE_W + GUTTER + CONTENT_W + CARD_PAD * 2
local PANEL_WIDTH = PAD * 2 + FULL_W
local CONTENT_TOP = -52                                -- Where a page starts
local WHITE = "Interface\\Buttons\\WHITE8x8"
local CIRCLE_MASK = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
local BAR_TEXTURE = "Interface\\TargetingFrame\\UI-StatusBar"
local FONT_UI = "Fonts\\FRIZQT__.TTF"
local ICON = "Interface\\AddOns\\MyXPBar\\Media\\icon"
local AUTHOR = "Made by Polarz141"

-- The accent of the menu. It used to be gold, with the parchment and the
-- gothic letters of the game around it; the menu is flat and dark now, and
-- the accent is the purple the bar wears out of the box. Everything that
-- was drawn in gold follows this one table.
local GOLD = { 0.56, 0.45, 0.95 }
local PANEL_BG = { 0.075, 0.078, 0.094 }
local CARD_BG = { 0.113, 0.118, 0.141 }
local FIELD_BG = { 0.145, 0.152, 0.180 }
local TEXT_HI = { 0.90, 0.91, 0.94 }
local TEXT_LO = { 0.58, 0.60, 0.67 }

-- Flat panels: a solid fill and a one pixel edge, nothing else
local DIALOG_BACKDROP = {
    bgFile = WHITE, edgeFile = WHITE, edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
}
local BOX_BACKDROP = DIALOG_BACKDROP

-- The font of the interface has no Cyrillic outside the Russian client:
-- those languages get a font that can show their letters
local FONT_FALLBACK = "Fonts\\ARIALN.TTF"
local fonts = {}

local function MakeFont(name, size, outline)
    local font = CreateFont(name)
    font:SetFont(FONT_UI, size, outline)
    font:SetShadowOffset(1, -1)
    font:SetShadowColor(0, 0, 0, 1)
    tinsert(fonts, { font = font, size = size, outline = outline })
    return font
end
local FontTitle = MakeFont("MyXPBarFontTitle", 15, "")
local FontSection = MakeFont("MyXPBarFontSection", 12, "")
local FontSmall = MakeFont("MyXPBarFontSmall", 11, "")

function ns.ApplyFonts()
    local path = ns.UsesLatinFont() and FONT_UI or FONT_FALLBACK
    for _, entry in ipairs(fonts) do
        pcall(entry.font.SetFont, entry.font, path, entry.size, entry.outline)
    end
end

local PRESETS = {
    { key = "VIOLET", r = 0.6,  g = 0.4,  b = 1 },
    { key = "BLUE",   r = 0.2,  g = 0.6,  b = 1 },
    { key = "CYAN",   r = 0.2,  g = 0.9,  b = 0.9 },
    { key = "GREEN",  r = 0.3,  g = 0.85, b = 0.4 },
    { key = "GOLD",   r = 1,    g = 0.8,  b = 0.2 },
    { key = "ORANGE", r = 1,    g = 0.5,  b = 0.15 },
    { key = "RED",    r = 0.95, g = 0.25, b = 0.3 },
    { key = "PINK",   r = 1,    g = 0.45, b = 0.8 },
}

local function Accent()
    local c = ns.db.xpColor
    return c.r, c.g, c.b
end

local function PlayUISound(key)
    if SOUNDKIT and SOUNDKIT[key] then PlaySound(SOUNDKIT[key]) end
end

local function MakeRound(tex)
    local parent = tex:GetParent()
    if not parent.CreateMaskTexture or not tex.AddMaskTexture then return end
    local mask = parent:CreateMaskTexture()
    mask:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(tex)
    tex:AddMaskTexture(mask)
end

local function SetGradientSafe(tex, orientation, r, g, b, a1, a2)
    tex:SetTexture(WHITE)
    local ok = CreateColor and pcall(tex.SetGradient, tex, orientation, CreateColor(r, g, b, a1), CreateColor(r, g, b, a2))
    if not ok then tex:SetVertexColor(r, g, b, (a1 + a2) / 2) end
end

-- Gold diamond (a rotated square), used in ornaments
local function Diamond(parent, size, layer)
    local d = parent:CreateTexture(nil, layer or "ARTWORK")
    d:SetTexture(WHITE)
    d:SetSize(size, size)
    d:SetVertexColor(GOLD[1], GOLD[2], GOLD[3])
    d:SetRotation(math.rad(45))
    return d
end

-- Gold line - diamond - gold line
local function Ornament(parent, width)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(width, 10)
    local center = Diamond(holder, 8)
    center:SetPoint("CENTER")
    local left = holder:CreateTexture(nil, "ARTWORK")
    left:SetHeight(1)
    left:SetPoint("LEFT")
    left:SetPoint("RIGHT", center, "LEFT", -7, 0)
    SetGradientSafe(left, "HORIZONTAL", GOLD[1], GOLD[2], GOLD[3], 0, 0.9)
    local right = holder:CreateTexture(nil, "ARTWORK")
    right:SetHeight(1)
    right:SetPoint("RIGHT")
    right:SetPoint("LEFT", center, "RIGHT", 7, 0)
    SetGradientSafe(right, "HORIZONTAL", GOLD[1], GOLD[2], GOLD[3], 0.9, 0)
    return holder
end

-- Anything that follows the XP color registers here (preview and swatches only)
local accentUpdaters = {}
local refreshers = {}
-- Every translated text registers here, so it can change language live
local localizedTexts = {}

local function RefreshAccent()
    local r, g, b = Accent()
    for _, fn in ipairs(accentUpdaters) do fn(r, g, b) end
end

local function Localize(fontString, key)
    fontString.l10nKey = key
    fontString:SetText(T(key))
    tinsert(localizedTexts, fontString)
end

-- =========================================================
-- MAIN PANEL
-- =========================================================
local panel = CreateFrame("Frame", "MyXPBarOptionsFrame", UIParent, "BackdropTemplate")
panel:SetSize(PANEL_WIDTH, 600)
panel:SetPoint("CENTER")
panel:SetFrameStrata("HIGH")
panel:SetToplevel(true)
panel:SetMovable(true)
panel:SetClampedToScreen(true)
panel:EnableMouse(true)
panel:SetBackdrop(DIALOG_BACKDROP)
panel:SetBackdropColor(PANEL_BG[1], PANEL_BG[2], PANEL_BG[3], 0.97)
panel:SetBackdropBorderColor(0, 0, 0, 1)
panel:Hide()
tinsert(UISpecialFrames, "MyXPBarOptionsFrame") -- Escape closes the menu

-- Header: a slim bar across the top, the name on the left, the cross on the
-- right. Dragging it moves the menu.
local HEADER_H = 38

local header = CreateFrame("Frame", nil, panel)
header:SetPoint("TOPLEFT", 1, -1)
header:SetPoint("TOPRIGHT", -1, -1)
header:SetHeight(HEADER_H)
header:EnableMouse(true)
header:SetScript("OnMouseDown", function() panel:StartMoving() end)
header:SetScript("OnMouseUp", function() panel:StopMovingOrSizing() end)

local headerBg = header:CreateTexture(nil, "BACKGROUND")
headerBg:SetAllPoints()
headerBg:SetColorTexture(CARD_BG[1], CARD_BG[2], CARD_BG[3], 1)

-- The one line of accent in the whole header, under it
local headerLine = header:CreateTexture(nil, "ARTWORK")
headerLine:SetHeight(1)
headerLine:SetPoint("BOTTOMLEFT")
headerLine:SetPoint("BOTTOMRIGHT")
headerLine:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.5)

local crestIcon = header:CreateTexture(nil, "ARTWORK")
crestIcon:SetSize(18, 18)
crestIcon:SetPoint("LEFT", 12, 0)
crestIcon:SetTexture(ICON)

local title = header:CreateFontString(nil, "OVERLAY")
title:SetFontObject(FontTitle)
title:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
title:SetPoint("LEFT", crestIcon, "RIGHT", 8, 0)
title:SetText("MyXPBar")

local versionText = header:CreateFontString(nil, "OVERLAY")
versionText:SetFontObject(FontSmall)
versionText:SetTextColor(TEXT_LO[1], TEXT_LO[2], TEXT_LO[3])
versionText:SetPoint("LEFT", title, "RIGHT", 8, -1)
versionText:SetText("v" .. VERSION)

-- A cross of our own: the Blizzard one is a big stone button. A square
-- with an edge, like every other field of the menu, so it does not look
-- like a letter dropped in the corner.
local closeButton = CreateFrame("Button", nil, header, "BackdropTemplate")
closeButton:SetSize(20, 20)
closeButton:SetPoint("RIGHT", -10, 0)
closeButton:SetFrameLevel(header:GetFrameLevel() + 10)
closeButton:SetBackdrop(BOX_BACKDROP)
closeButton:SetBackdropColor(FIELD_BG[1], FIELD_BG[2], FIELD_BG[3], 1)
closeButton:SetBackdropBorderColor(1, 1, 1, 0.10)
local closeX = closeButton:CreateFontString(nil, "OVERLAY")
closeX:SetFontObject(FontSmall)
closeX:SetPoint("CENTER", 0, 0)
closeX:SetText("X")
closeX:SetTextColor(TEXT_LO[1], TEXT_LO[2], TEXT_LO[3])
closeButton:SetScript("OnEnter", function(self)
    self:SetBackdropColor(0.72, 0.22, 0.26, 1)
    self:SetBackdropBorderColor(0.85, 0.3, 0.34, 1)
    closeX:SetTextColor(1, 1, 1)
end)
closeButton:SetScript("OnLeave", function(self)
    self:SetBackdropColor(FIELD_BG[1], FIELD_BG[2], FIELD_BG[3], 1)
    self:SetBackdropBorderColor(1, 1, 1, 0.10)
    closeX:SetTextColor(TEXT_LO[1], TEXT_LO[2], TEXT_LO[3])
end)
closeButton:SetScript("OnClick", function() panel:Hide() end)

-- A page is a frame holding its own widgets. They all sit at the same place
-- and only the chosen one is shown, so the menu is as tall as its tallest
-- page instead of as tall as everything it holds.
local function MakeColumn(width)
    local column = CreateFrame("Frame", nil, panel)
    column:SetSize(width, 10)
    return column
end

local footer = MakeColumn(FULL_W)
local pages = {}

-- Widgets are created in "content", stacked downwards from cursorY
local content
local cursorY = 0

-- Every section is drawn inside a card: a darker box with a one pixel edge
-- around the widgets that belong together. Its height is only known once
-- the next section starts, or the page ends.
local openCard

local function CloseCard()
    if not openCard then return end
    local card = openCard.frame
    card:ClearAllPoints()
    card:SetPoint("TOPLEFT", content, "TOPLEFT", -CARD_PAD, openCard.top)
    card:SetPoint("TOPRIGHT", content, "TOPRIGHT", CARD_PAD, openCard.top)
    card:SetHeight(math.max(openCard.top - cursorY + CARD_PAD, 24))
    -- The page is as tall as its cards, padding included: without this the
    -- last card of a page ran under the footer
    cursorY = cursorY - CARD_PAD
    openCard = nil
end

local function FinishColumn()
    CloseCard()
    if content then content:SetHeight(math.max(-cursorY, 10)) end
end

-- Opens a page and adds it to the list on the left
local function StartPage(key)
    FinishColumn()
    content = MakeColumn(CONTENT_W)
    cursorY = 0
    tinsert(pages, { frame = content, key = key })
end

local function StartFooter()
    FinishColumn()
    content = footer
    cursorY = 0
end

-- The page on screen. Set once the list of pages is built.
local currentPage = 1

-- =========================================================
-- WIDGETS
-- =========================================================
local function Section(key)
    CloseCard()
    cursorY = cursorY - 12

    local card = CreateFrame("Frame", nil, content, "BackdropTemplate")
    card:SetBackdrop(BOX_BACKDROP)
    card:SetBackdropColor(CARD_BG[1], CARD_BG[2], CARD_BG[3], 1)
    card:SetBackdropBorderColor(1, 1, 1, 0.09)
    -- Under the widgets, which are children of the page like the card is
    card:SetFrameLevel(math.max(content:GetFrameLevel(), 1))
    openCard = { frame = card, top = cursorY }

    cursorY = cursorY - 10

    -- A short accent bar, then the name of the section
    local mark = content:CreateTexture(nil, "ARTWORK")
    mark:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.9)
    mark:SetSize(2, 11)
    mark:SetPoint("TOPLEFT", 0, cursorY - 1)

    local label = content:CreateFontString(nil, "OVERLAY")
    label:SetFontObject(FontSection)
    label:SetTextColor(TEXT_HI[1], TEXT_HI[2], TEXT_HI[3])
    label:SetPoint("TOPLEFT", 8, cursorY)
    Localize(label, key)

    local line = content:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", label, "TOPRIGHT", 10, -7)
    line:SetPoint("TOPRIGHT", content, "TOPLEFT", CONTENT_W, cursorY - 7)
    line:SetColorTexture(1, 1, 1, 0.07)

    cursorY = cursorY - 24
end

local function CreateSlider(key, minV, maxV, step, getValue, setValue, formatValue)
    local holder = CreateFrame("Frame", nil, content)
    holder:SetSize(CONTENT_W, 42)
    holder:SetPoint("TOPLEFT", 0, cursorY)
    cursorY = cursorY - 44

    local label = holder:CreateFontString(nil, "OVERLAY")
    label:SetFontObject(FontSmall)
    label:SetTextColor(TEXT_HI[1], TEXT_HI[2], TEXT_HI[3])
    label:SetPoint("TOPLEFT", 0, -2)
    Localize(label, key)

    -- The number sits in a field of its own, on the right of the label
    local valueBox = CreateFrame("Frame", nil, holder, "BackdropTemplate")
    valueBox:SetSize(62, 18)
    valueBox:SetPoint("TOPRIGHT", 0, 0)
    valueBox:SetBackdrop(BOX_BACKDROP)
    valueBox:SetBackdropColor(FIELD_BG[1], FIELD_BG[2], FIELD_BG[3], 1)
    valueBox:SetBackdropBorderColor(1, 1, 1, 0.10)

    local valueText = valueBox:CreateFontString(nil, "OVERLAY")
    valueText:SetFontObject(FontSmall)
    valueText:SetTextColor(TEXT_HI[1], TEXT_HI[2], TEXT_HI[3])
    valueText:SetPoint("CENTER")

    local slider = CreateFrame("Slider", nil, holder)
    slider:SetOrientation("HORIZONTAL")
    slider:SetSize(CONTENT_W, 18)
    slider:SetPoint("TOPLEFT", 0, -20)
    -- maxV can be a function, for limits that depend on the screen
    local function Max() return type(maxV) == "function" and maxV() or maxV end
    slider:SetMinMaxValues(minV, Max())
    slider:SetValueStep(step)
    if slider.SetObeyStepDuringDrag then slider:SetObeyStepDuringDrag(true) end
    slider:SetHitRectInsets(0, 0, -4, -4)

    -- Track: a flat dark rail
    local track = slider:CreateTexture(nil, "BACKGROUND")
    track:SetColorTexture(0.05, 0.052, 0.062, 1)
    track:SetHeight(5)
    track:SetPoint("LEFT")
    track:SetPoint("RIGHT")

    local thumb = slider:CreateTexture(nil, "OVERLAY")
    thumb:SetTexture(WHITE)
    thumb:SetVertexColor(GOLD[1], GOLD[2], GOLD[3])
    thumb:SetSize(10, 14)
    slider:SetThumbTexture(thumb)

    local fill = slider:CreateTexture(nil, "ARTWORK")
    fill:SetHeight(5)
    fill:SetPoint("LEFT", track, "LEFT")
    fill:SetPoint("RIGHT", thumb, "CENTER")
    fill:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.85)

    local updating = false
    slider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value / step + 0.5) * step
        valueText:SetText(formatValue(value))
        if not updating then setValue(value) end
    end)

    slider:EnableMouseWheel(true)
    slider:SetScript("OnMouseWheel", function(self, delta)
        self:SetValue(self:GetValue() + delta * step)
    end)
    slider:SetScript("OnEnter", function() thumb:SetSize(12, 16) end)
    slider:SetScript("OnLeave", function() thumb:SetSize(10, 14) end)

    tinsert(refreshers, function()
        updating = true
        slider:SetMinMaxValues(minV, Max())
        slider:SetValue(getValue())
        valueText:SetText(formatValue(getValue()))
        updating = false
    end)
end

local function OpenColorPicker(r, g, b, callback)
    local function onChange()
        callback(ColorPickerFrame:GetColorRGB())
    end
    local function onCancel()
        callback(r, g, b)
    end
    if ColorPickerFrame.SetupColorPickerAndShow then
        ColorPickerFrame:SetupColorPickerAndShow({
            r = r, g = g, b = b,
            hasOpacity = false,
            swatchFunc = onChange,
            cancelFunc = onCancel,
        })
    else
        ColorPickerFrame.hasOpacity = false
        ColorPickerFrame.previousValues = { r, g, b }
        ColorPickerFrame.func = onChange
        ColorPickerFrame.cancelFunc = onCancel
        ColorPickerFrame:SetColorRGB(r, g, b)
        ShowUIPanel(ColorPickerFrame)
    end
    ColorPickerFrame:SetFrameStrata("FULLSCREEN_DIALOG")
end

local function CreateColorRow(labelKey, key)
    local row = CreateFrame("Frame", nil, content)
    row:SetSize(CONTENT_W, 26)
    row:SetPoint("TOPLEFT", 0, cursorY)
    cursorY = cursorY - 34

    local label = row:CreateFontString(nil, "OVERLAY")
    label:SetFontObject(FontSmall)
    label:SetTextColor(TEXT_HI[1], TEXT_HI[2], TEXT_HI[3])
    label:SetPoint("LEFT")
    Localize(label, labelKey)

    local function SetColor(r, g, b)
        local c = ns.db[key]
        c.r, c.g, c.b = r, g, b
        ns.Refresh()
        ns.RefreshOptions()
    end

    -- Quick colors, framed like small gems
    local dots = {}
    for i, preset in ipairs(PRESETS) do
        local dot = CreateFrame("Button", nil, row, "BackdropTemplate")
        dot:SetSize(20, 20)
        dot:SetPoint("LEFT", 122 + (i - 1) * 24, 0)
        dot:SetBackdrop({ edgeFile = WHITE, edgeSize = 1 })
        dot:SetBackdropBorderColor(1, 1, 1, 0.12)

        local swatch = dot:CreateTexture(nil, "ARTWORK")
        swatch:SetPoint("TOPLEFT", 3, -3)
        swatch:SetPoint("BOTTOMRIGHT", -3, 3)
        swatch:SetTexture(WHITE)
        swatch:SetVertexColor(preset.r, preset.g, preset.b)

        dot.preset = preset
        dot:SetScript("OnEnter", function(self)
            self:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], 1)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(T(preset.key), preset.r, preset.g, preset.b)
            GameTooltip:Show()
        end)
        dot:SetScript("OnLeave", function(self)
            self:SetBackdropBorderColor(self.selected and GOLD[1] or 1, self.selected and GOLD[2] or 1, self.selected and GOLD[3] or 1, self.selected and 1 or 0.12)
            GameTooltip:Hide()
        end)
        dot:SetScript("OnClick", function()
            PlayUISound("IG_MAINMENU_OPTION_CHECKBOX_ON")
            SetColor(preset.r, preset.g, preset.b)
        end)
        dots[i] = dot
    end

    -- Custom color: opens the Blizzard color wheel
    local custom = CreateFrame("Button", nil, row, "BackdropTemplate")
    custom:SetSize(36, 20)
    custom:SetPoint("RIGHT")
    custom:SetBackdrop(BOX_BACKDROP)
    custom:SetBackdropColor(FIELD_BG[1], FIELD_BG[2], FIELD_BG[3], 1)
    custom:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], 1)
    local customColor = custom:CreateTexture(nil, "ARTWORK")
    customColor:SetPoint("TOPLEFT", 5, -5)
    customColor:SetPoint("BOTTOMRIGHT", -5, 5)
    customColor:SetTexture(WHITE)
    custom:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(T("CUSTOM_COLOR"))
        GameTooltip:AddLine(T("CUSTOM_COLOR_DESC"), 1, 1, 1, true)
        GameTooltip:Show()
    end)
    custom:SetScript("OnLeave", function() GameTooltip:Hide() end)
    custom:SetScript("OnClick", function()
        local c = ns.db[key]
        OpenColorPicker(c.r, c.g, c.b, SetColor)
    end)

    tinsert(refreshers, function()
        local c = ns.db[key]
        customColor:SetVertexColor(c.r, c.g, c.b)
        for _, dot in ipairs(dots) do
            local p = dot.preset
            dot.selected = math.abs(p.r - c.r) < 0.01 and math.abs(p.g - c.g) < 0.01 and math.abs(p.b - c.b) < 0.01
            if dot.selected then
                dot:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], 1)
            else
                dot:SetBackdropBorderColor(1, 1, 1, 0.12)
            end
        end
    end)
end

-- Blizzard checkboxes, two per row
local checkIndex = 0
-- wide: the label needs the whole width, so the box sits alone on its row
local function CreateCheck(labelKey, descKey, getValue, setValue, wide)
    if wide and checkIndex % 2 == 1 then
        cursorY = cursorY - 28
        checkIndex = 0
    end
    local col = wide and 0 or (checkIndex % 2)
    -- A small square of our own, instead of the round wooden box of the game
    local check = CreateFrame("CheckButton", nil, content, "BackdropTemplate")
    check:SetSize(16, 16)
    check:SetPoint("TOPLEFT", col * (CONTENT_W / 2 + 6), cursorY - 3)
    check:SetBackdrop(BOX_BACKDROP)
    check:SetBackdropColor(FIELD_BG[1], FIELD_BG[2], FIELD_BG[3], 1)
    check:SetBackdropBorderColor(1, 1, 1, 0.14)
    if wide or col == 1 then cursorY = cursorY - 28 end
    checkIndex = wide and 0 or (checkIndex + 1)

    local tick = check:CreateTexture(nil, "OVERLAY")
    tick:SetPoint("TOPLEFT", -2, 2)
    tick:SetPoint("BOTTOMRIGHT", 2, -2)
    tick:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    tick:SetVertexColor(GOLD[1], GOLD[2], GOLD[3])
    check:SetCheckedTexture(tick)

    local label = check:CreateFontString(nil, "OVERLAY")
    label:SetFontObject(FontSmall)
    label:SetTextColor(TEXT_HI[1], TEXT_HI[2], TEXT_HI[3])
    label:SetPoint("LEFT", check, "RIGHT", 7, 0)
    label:SetWidth((wide and CONTENT_W or CONTENT_W / 2) - 38)
    label:SetJustifyH("LEFT")
    Localize(label, labelKey)

    check:HookScript("OnEnter", function(self)
        self:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], 0.8)
    end)
    check:HookScript("OnLeave", function(self)
        self:SetBackdropBorderColor(1, 1, 1, 0.14)
    end)

    check:SetScript("OnClick", function(self)
        setValue(self:GetChecked() and true or false)
        PlayUISound(self:GetChecked() and "IG_MAINMENU_OPTION_CHECKBOX_ON" or "IG_MAINMENU_OPTION_CHECKBOX_OFF")
        ns.Refresh()
        ns.RefreshOptions()
    end)
    check:SetScript("OnEnter", function(self)
        if not descKey then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(T(labelKey))
        GameTooltip:AddLine(T(descKey), 1, 1, 1, true)
        GameTooltip:Show()
    end)
    check:SetScript("OnLeave", function() GameTooltip:Hide() end)

    tinsert(refreshers, function() check:SetChecked(getValue()) end)
    return check
end

-- Closes the current row, so the next group starts on the left again
local function EndChecks()
    if checkIndex % 2 == 1 then cursorY = cursorY - 28 end
    checkIndex = 0
end

local function OptionCheck(labelKey, descKey, dbKey, onChange)
    CreateCheck(labelKey, descKey,
        function() return ns.db[dbKey] end,
        function(v)
            ns.db[dbKey] = v
            if onChange then onChange() end
        end)
end

-- A flat button: a dark field, a one pixel edge, the accent on hover.
-- Everything clickable in the menu is built from this, in place of the
-- stone buttons of the game.
local function SkinField(frame)
    frame:SetBackdrop(BOX_BACKDROP)
    frame:SetBackdropColor(FIELD_BG[1], FIELD_BG[2], FIELD_BG[3], 1)
    frame:SetBackdropBorderColor(1, 1, 1, 0.10)
end

local function MakeFlatButton(parent, width, height)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(width, height)
    SkinField(b)

    local fs = b:CreateFontString(nil, "OVERLAY")
    fs:SetFontObject(FontSmall)
    fs:SetPoint("CENTER", 0, 0)
    fs:SetTextColor(TEXT_HI[1], TEXT_HI[2], TEXT_HI[3])
    b:SetFontString(fs)
    b.Text = fs

    -- The page or the style in use stays lit: LockHighlight is ours here,
    -- the template that used to answer it is gone
    b.lit = b:CreateTexture(nil, "BACKGROUND")
    b.lit:SetAllPoints()
    b.lit:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.22)
    b.lit:Hide()
    function b:LockHighlight()
        self.lit:Show()
        self:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], 0.9)
    end
    function b:UnlockHighlight()
        self.lit:Hide()
        self:SetBackdropBorderColor(1, 1, 1, 0.10)
    end

    b:HookScript("OnEnter", function(self)
        if self.lit:IsShown() then return end
        self:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], 0.55)
    end)
    b:HookScript("OnLeave", function(self)
        if self.lit:IsShown() then return end
        self:SetBackdropBorderColor(1, 1, 1, 0.10)
    end)
    b:SetScript("OnDisable", function(self)
        self.Text:SetTextColor(0.4, 0.41, 0.45)
    end)
    b:SetScript("OnEnable", function(self)
        self.Text:SetTextColor(TEXT_HI[1], TEXT_HI[2], TEXT_HI[3])
    end)
    return b
end

local function CreateButton(parent, labelKey, width, height, onClick)
    local b = MakeFlatButton(parent, width, height)
    b:SetText(T(labelKey))
    Localize(b.Text, labelKey)
    b:SetScript("OnClick", function()
        PlayUISound("IG_MAINMENU_OPTION_CHECKBOX_ON")
        onClick()
    end)
    return b
end

-- A title and an explanation, on anything the mouse can reach
local function Tip(frame, labelKey, descKey, anchor)
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, anchor or "ANCHOR_RIGHT")
        GameTooltip:SetText(T(labelKey))
        GameTooltip:AddLine(T(descKey), 1, 1, 1, true)
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- =========================================================
-- CONTENT
-- =========================================================
StartPage("PAGE_BAR")
Section("SECTION_PREVIEW")
local previewBox = CreateFrame("Frame", nil, content, "BackdropTemplate")
previewBox:SetSize(CONTENT_W, 64)
previewBox:SetPoint("TOPLEFT", 0, cursorY)
previewBox:SetBackdrop(BOX_BACKDROP)
previewBox:SetBackdropColor(0.055, 0.058, 0.07, 1)
previewBox:SetBackdropBorderColor(1, 1, 1, 0.09)
cursorY = cursorY - 76

local previewBg = previewBox:CreateTexture(nil, "BACKGROUND", nil, 2)
local previewRested = CreateFrame("StatusBar", nil, previewBox)
previewRested:SetStatusBarTexture(BAR_TEXTURE)
previewRested:SetMinMaxValues(0, 100)
previewRested:SetValue(82)
local previewXP = CreateFrame("StatusBar", nil, previewBox)
previewXP:SetStatusBarTexture(BAR_TEXTURE)
previewXP:SetMinMaxValues(0, 100)
previewXP:SetValue(58)
previewXP:SetFrameLevel(previewRested:GetFrameLevel() + 1)
local previewLevel = previewXP:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
previewLevel:SetPoint("LEFT", 5, 0)
previewLevel:SetTextColor(1, 1, 1)
local previewPct = previewXP:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
previewPct:SetPoint("RIGHT", -5, 0)
previewPct:SetTextColor(1, 1, 1)
previewPct:SetText("58.0% (82.0%)")

-- The preview shows the chosen style too
local previewBorder = CreateFrame("Frame", nil, previewBox, "BackdropTemplate")
previewBorder:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12 })
previewBorder:SetBackdropBorderColor(0.85, 0.68, 0.3, 1)
previewBorder:Hide()

local previewSegments = {}
for i = 1, 19 do
    local seg = previewXP:CreateTexture(nil, "OVERLAY")
    seg:SetColorTexture(0, 0, 0, 0.8)
    seg:SetWidth(2)
    seg:Hide()
    previewSegments[i] = seg
end

local previewSpark = previewBox:CreateTexture(nil, "OVERLAY")
previewSpark:SetTexture(WHITE)
previewSpark:SetBlendMode("ADD")
previewSpark:SetWidth(8)
previewSpark:Hide()

local previewUnder = CreateFrame("StatusBar", nil, previewBox)
previewUnder:SetStatusBarTexture(BAR_TEXTURE)
previewUnder:SetMinMaxValues(0, 100)
previewUnder:SetValue(82)
previewUnder:SetHeight(4)
previewUnder:Hide()

local function RefreshPreview()
    local db = ns.db
    local style = db.style or "classic"
    local width = CONTENT_W - 28
    local h = math.min(db.height, 44)
    if style == "thin" then h = 6 end

    previewXP:ClearAllPoints()
    previewXP:SetSize(width, h)
    previewXP:SetPoint("CENTER", previewBox, "CENTER", 0, style == "restedbar" and 4 or 0)
    previewRested:SetAllPoints(previewXP)
    previewBg:SetAllPoints(previewXP)
    previewBg:SetColorTexture(0, 0, 0, db.bgAlpha)

    local texture = ns.TextureFile(db.texture)
    previewXP:SetStatusBarTexture(texture)
    previewRested:SetStatusBarTexture(texture)
    previewUnder:SetStatusBarTexture(texture)

    local c, rc = db.xpColor, db.restedColor
    previewXP:SetStatusBarColor(c.r, c.g, c.b, 1)
    previewRested:SetStatusBarColor(rc.r, rc.g, rc.b, 0.5)
    previewUnder:SetStatusBarColor(rc.r, rc.g, rc.b, 1)

    previewBorder:SetShown(style == "gold")
    previewBorder:ClearAllPoints()
    previewBorder:SetPoint("TOPLEFT", previewXP, "TOPLEFT", -2, 2)
    previewBorder:SetPoint("BOTTOMRIGHT", previewXP, "BOTTOMRIGHT", 2, -2)

    for i, seg in ipairs(previewSegments) do
        seg:SetShown(style == "segments")
        seg:ClearAllPoints()
        seg:SetPoint("TOP", previewXP, "TOPLEFT", width * i / 20, 0)
        seg:SetPoint("BOTTOM", previewXP, "BOTTOMLEFT", width * i / 20, 0)
    end

    previewSpark:SetShown(style == "spark")
    previewSpark:SetHeight(h + 8)
    previewSpark:SetVertexColor(math.min(c.r + 0.4, 1), math.min(c.g + 0.4, 1), math.min(c.b + 0.4, 1), 0.9)
    previewSpark:ClearAllPoints()
    previewSpark:SetPoint("CENTER", previewXP, "LEFT", width * 0.58, 0)

    previewUnder:SetShown(style == "restedbar")
    previewRested:SetShown(style ~= "restedbar")
    previewUnder:ClearAllPoints()
    previewUnder:SetPoint("TOPLEFT", previewXP, "BOTTOMLEFT", 0, -2)
    previewUnder:SetPoint("TOPRIGHT", previewXP, "BOTTOMRIGHT", 0, -2)

    previewLevel:SetText(T("BAR_LEVEL") .. " 42")
    previewLevel:SetShown(db.showText and h >= 12)
    previewPct:SetShown(db.showText and h >= 12)
end
tinsert(refreshers, RefreshPreview)

-- Bar styles: two rows of three buttons
Section("SECTION_STYLE")
local STYLES = {
    { id = "classic", key = "STYLE_CLASSIC" },
    { id = "gold", key = "STYLE_GOLD" },
    { id = "segments", key = "STYLE_SEGMENTS" },
    { id = "thin", key = "STYLE_THIN" },
    { id = "spark", key = "STYLE_SPARK" },
    { id = "restedbar", key = "STYLE_RESTEDBAR" },
}
local styleButtons = {}
for i, style in ipairs(STYLES) do
    local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
    local b = CreateButton(content, style.key, CONTENT_W / 3 - 6, 24, function()
        ns.db.style = style.id
        ns.Refresh()
        ns.RefreshOptions()
    end)
    b:SetPoint("TOPLEFT", col * (CONTENT_W / 3), cursorY - row * 28)
    b.style = style.id
    styleButtons[i] = b
end
cursorY = cursorY - 62
tinsert(refreshers, function()
    for _, b in ipairs(styleButtons) do
        if b.style == ns.db.style then b:LockHighlight() else b:UnlockHighlight() end
    end
end)

EndChecks()
OptionCheck("RESTED_ABOVE", "RESTED_ABOVE_DESC", "restedAbove")
EndChecks()
cursorY = cursorY - 10

-- Bar texture: a drop-down showing each texture under its name. Same shape
-- as the language one at the bottom of the menu, including the list living
-- in UIParent (the panel is toplevel and would cover it, eating the clicks).
Section("SECTION_TEXTURE")
local TEX_W, TEX_ROW = CONTENT_W, 24

local function PaintSwatch(fill, entry, chosen)
    local c = ns.db.xpColor
    fill:SetTexture(entry.file)
    fill:SetVertexColor(c.r, c.g, c.b, chosen and 0.95 or 0.55)
end

local texButton = CreateFrame("Button", nil, content)
texButton:SetSize(TEX_W, TEX_ROW)
texButton:SetPoint("TOPLEFT", 0, cursorY)
texButton.fill = texButton:CreateTexture(nil, "ARTWORK")
texButton.fill:SetPoint("TOPLEFT", 1, -1)
texButton.fill:SetPoint("BOTTOMRIGHT", -1, 1)
texButton.edge = CreateFrame("Frame", nil, texButton, "BackdropTemplate")
texButton.edge:SetAllPoints()
texButton.edge:SetBackdrop({ edgeFile = WHITE, edgeSize = 1 })
texButton.edge:SetBackdropBorderColor(1, 1, 1, 0.12)
texButton.label = texButton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
texButton.label:SetPoint("LEFT", 8, 0)
texButton.label:SetShadowOffset(1, -1)
texButton.label:SetShadowColor(0, 0, 0, 1)

local texArrow = texButton:CreateTexture(nil, "OVERLAY")
texArrow:SetSize(7, 7)
texArrow:SetPoint("RIGHT", -8, 0)
texArrow:SetTexture(WHITE)
texArrow:SetVertexColor(GOLD[1], GOLD[2], GOLD[3])
texArrow:SetRotation(math.rad(45))

local texList = CreateFrame("Frame", "MyXPBarTextureList", UIParent, "BackdropTemplate")
texList:SetFrameStrata("FULLSCREEN_DIALOG")
texList:SetToplevel(true)
texList:SetBackdrop(BOX_BACKDROP)
texList:SetBackdropColor(CARD_BG[1], CARD_BG[2], CARD_BG[3], 0.98)
texList:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], 0.6)
texList:SetSize(TEX_W, 10 + #ns.TEXTURES * TEX_ROW)
texList:SetPoint("TOPLEFT", texButton, "BOTTOMLEFT", 0, 0)
texList:EnableMouse(true)
texList:Hide()

local texEntries = {}
for i, entry in ipairs(ns.TEXTURES) do
    local item = CreateFrame("Button", nil, texList)
    item:SetSize(TEX_W - 10, TEX_ROW - 2)
    item:SetPoint("TOPLEFT", 5, -5 - (i - 1) * TEX_ROW)

    item.fill = item:CreateTexture(nil, "ARTWORK")
    item.fill:SetAllPoints()

    item.highlight = item:CreateTexture(nil, "OVERLAY")
    item.highlight:SetAllPoints()
    item.highlight:SetColorTexture(1, 1, 1, 0.18)
    item.highlight:Hide()

    item.text = item:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    item.text:SetPoint("LEFT", 8, 0)
    item.text:SetShadowOffset(1, -1)
    item.text:SetShadowColor(0, 0, 0, 1)
    Localize(item.text, entry.key)

    item.id = entry.id
    item.entry = entry
    item:SetScript("OnEnter", function(self) self.highlight:Show() end)
    item:SetScript("OnLeave", function(self) self.highlight:Hide() end)
    item:SetScript("OnClick", function(self)
        texList:Hide()
        if ns.db.texture == self.id then return end
        PlayUISound("IG_MAINMENU_OPTION_CHECKBOX_ON")
        ns.db.texture = self.id
        ns.Refresh()
        ns.RefreshOptions()
    end)
    texEntries[i] = item
end

texButton:SetScript("OnClick", function()
    PlayUISound("IG_MAINMENU_OPTION_CHECKBOX_ON")
    texList:SetShown(not texList:IsShown())
end)

-- Closes a short moment after the mouse left both the button and the list,
-- so going from one to the other never closes it
local TEX_GRACE = 0.6
local texAway = 0
texList:SetScript("OnShow", function() texAway = 0 end)
texList:SetScript("OnUpdate", function(self, elapsed)
    if self:IsMouseOver(4, -4, -4, 4) or texButton:IsMouseOver(4, -4, -4, 4) then
        texAway = 0
        return
    end
    texAway = texAway + elapsed
    if texAway > TEX_GRACE then self:Hide() end
end)
panel:HookScript("OnHide", function() texList:Hide() end)

cursorY = cursorY - TEX_ROW - 10

tinsert(refreshers, function()
    local current = ns.TextureEntry(ns.db.texture)
    PaintSwatch(texButton.fill, current, true)
    texButton.label:SetText(T(current.key))
    for _, item in ipairs(texEntries) do
        PaintSwatch(item.fill, item.entry, item.id == ns.db.texture)
        item.text:SetTextColor(1, 1, 1, item.id == ns.db.texture and 1 or 0.8)
    end
end)

-- Font of the texts of the bar: one button per font, each written in the
-- font it picks. Four of the game's own, so there is no file to ship.
StartPage("PAGE_TEXT")
Section("SECTION_FONT")
-- A drop-down of every font: the five of the addon, then the ones another
-- addon registered with LibSharedMedia, if any addon brought the library.
-- Each line is written in the font it picks, and the list scrolls when it
-- holds more than fits.
local FONT_ROW, FONT_ROWS = 22, 12
local fontEntries, fontOffset = {}, 0
local fontRows = {}

local function FontLabel(entry)
    return entry.name or T(entry.key)
end

local function PaintFontText(fontString, entry, size)
    if entry.file then
        if pcall(fontString.SetFont, fontString, entry.file, size, entry.flags or "") then return end
    end
    fontString:SetFontObject(FontSmall)
end

local fontButton = MakeFlatButton(content, CONTENT_W, 24)
fontButton:SetPoint("TOPLEFT", 0, cursorY)
cursorY = cursorY - 32

local fontArrow = fontButton:CreateTexture(nil, "OVERLAY")
fontArrow:SetSize(7, 7)
fontArrow:SetPoint("RIGHT", -8, 0)
fontArrow:SetTexture(WHITE)
fontArrow:SetVertexColor(GOLD[1], GOLD[2], GOLD[3])
fontArrow:SetRotation(math.rad(45))

-- The list belongs to the panel and sits sixty levels above it, instead of
-- floating in UIParent at another strata: that is what kept it from ever
-- showing up in game, and a level inside the panel cannot be covered.
local fontCatcher = CreateFrame("Button", nil, panel)
fontCatcher:SetAllPoints(panel)
fontCatcher:SetFrameLevel(panel:GetFrameLevel() + 55)
fontCatcher:Hide()

local fontList = CreateFrame("Frame", "MyXPBarFontList", panel, "BackdropTemplate")
fontList:SetFrameLevel(panel:GetFrameLevel() + 60)
fontList:SetBackdrop(BOX_BACKDROP)
fontList:SetBackdropColor(CARD_BG[1], CARD_BG[2], CARD_BG[3], 0.98)
fontList:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], 0.6)
fontList:SetPoint("TOPLEFT", fontButton, "BOTTOMLEFT", 0, -2)
fontList:EnableMouse(true)
fontList:EnableMouseWheel(true)
fontList:Hide()

local function CloseFontList()
    fontList:Hide()
    fontCatcher:Hide()
end
fontCatcher:SetScript("OnClick", CloseFontList)

local function FillFontRows()
    local shown = math.min(#fontEntries, FONT_ROWS)
    fontOffset = math.max(0, math.min(fontOffset, #fontEntries - shown))
    fontList:SetSize(CONTENT_W, 10 + shown * FONT_ROW)
    for i = 1, shown do
        local row = fontRows[i]
        if not row then
            row = CreateFrame("Button", nil, fontList)
            row:SetSize(CONTENT_W - 10, FONT_ROW - 2)
            row:SetPoint("TOPLEFT", 5, -5 - (i - 1) * FONT_ROW)
            row.highlight = row:CreateTexture(nil, "BACKGROUND")
            row.highlight:SetAllPoints()
            row.highlight:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.22)
            row.highlight:Hide()
            row.text = row:CreateFontString(nil, "OVERLAY")
            row.text:SetPoint("LEFT", 8, 0)
            row.text:SetPoint("RIGHT", -8, 0)
            row.text:SetJustifyH("LEFT")
            row:SetScript("OnEnter", function(self) self.highlight:Show() end)
            row:SetScript("OnLeave", function(self) self.highlight:Hide() end)
            row:SetScript("OnClick", function(self)
                CloseFontList()
                if ns.db.font == self.id then return end
                PlayUISound("IG_MAINMENU_OPTION_CHECKBOX_ON")
                ns.db.font = self.id
                ns.Refresh()
                ns.RefreshOptions()
            end)
            fontRows[i] = row
        end
        local entry = fontEntries[i + fontOffset]
        row.id = entry.id
        row.text:SetText(FontLabel(entry))
        PaintFontText(row.text, entry, 13)
        row.text:SetTextColor(1, 1, 1, entry.id == ns.db.font and 1 or 0.78)
        row:Show()
    end
    for i = shown + 1, #fontRows do fontRows[i]:Hide() end
end

fontList:SetScript("OnMouseWheel", function(self, delta)
    fontOffset = fontOffset - delta
    FillFontRows()
end)

fontButton:SetScript("OnClick", function()
    PlayUISound("IG_MAINMENU_OPTION_CHECKBOX_ON")
    if fontList:IsShown() then
        CloseFontList()
        return
    end
    fontEntries = ns.FontList()
    -- Open on the font in use, so a long list does not start from the top
    for i, entry in ipairs(fontEntries) do
        if entry.id == ns.db.font then fontOffset = i - 1 end
    end
    FillFontRows()
    fontCatcher:Show()
    fontList:Show()
end)

panel:HookScript("OnHide", CloseFontList)

tinsert(refreshers, function()
    local entry = ns.FontEntry(ns.db.font)
    fontButton:SetText(FontLabel(entry))
    PaintFontText(fontButton.Text, entry, 13)
    if fontList:IsShown() then FillFontRows() end
end)

Section("SECTION_TEXTS")
-- The size every text of the bar is multiplied by, kept as a percentage
CreateSlider("TEXT_SIZE", 70, 150, 5,
    function() return math.floor((ns.db.textScale or 1) * 100 + 0.5) end,
    function(v) ns.db.textScale = v / 100; ns.Refresh() end,
    function(v) return v .. " %" end)

EndChecks()
OptionCheck("SHOW_TEXT", "SHOW_TEXT_DESC", "showText")
OptionCheck("SHOW_LEVEL_TEXT", "SHOW_LEVEL_TEXT_DESC", "showLevelText")
OptionCheck("SHOW_VALUE_TEXT", "SHOW_VALUE_TEXT_DESC", "showValueText")
OptionCheck("SHOW_PCT_TEXT", "SHOW_PCT_TEXT_DESC", "showPctText")
OptionCheck("SHOW_RESTED", "SHOW_RESTED_DESC", "showRestedText")
OptionCheck("SHOW_SESSION", "SHOW_SESSION_DESC", "showSession")
EndChecks()
cursorY = cursorY - 10

StartPage("PAGE_SIZE")
Section("SECTION_SIZE")
-- Up to the width of the screen (in UI units, so it matches any resolution and UI scale)
CreateSlider("WIDTH", 200, function() return math.max(1400, math.floor(UIParent:GetWidth() / 10 + 0.5) * 10) end, 10,
    function() return ns.db.width end,
    function(v) ns.db.width = v; ns.Refresh() end,
    function(v) return v .. " px" end)
CreateSlider("HEIGHT", 8, 60, 1,
    function() return ns.db.height end,
    function(v) ns.db.height = v; ns.Refresh(); RefreshPreview() end,
    function(v) return v .. " px" end)

-- 0: the next level. Anything above is an estimate (see SessionLine)
CreateSlider("TARGET_LEVEL", 0, 60, 1,
    function() return ns.db.targetLevel or 0 end,
    function(v) ns.db.targetLevel = v; ns.Refresh() end,
    function(v) return v == 0 and T("TARGET_NEXT") or (T("BAR_LEVEL") .. " " .. v) end)

Section("SECTION_COLORS")
CreateColorRow("XP_COLOR", "xpColor")
CreateColorRow("RESTED_COLOR", "restedColor")
CreateSlider("BG_OPACITY", 0, 100, 5,
    function() return math.floor(ns.db.bgAlpha * 100 + 0.5) end,
    function(v) ns.db.bgAlpha = v / 100; ns.Refresh(); RefreshPreview() end,
    function(v) return v .. " %" end)

StartPage("PAGE_OPTIONS")
Section("SECTION_OPTIONS")
EndChecks()
OptionCheck("ENABLED", "ENABLED_DESC", "enabled")
OptionCheck("LOCK", "LOCK_DESC", "locked")
OptionCheck("HIDE_BLIZZARD", "HIDE_BLIZZARD_DESC", "hideBlizzard")
OptionCheck("SOUND", nil, "playSound")
OptionCheck("SMOOTH", "SMOOTH_DESC", "smooth")
OptionCheck("SHOW_GAINS", "SHOW_GAINS_DESC", "showGains")
OptionCheck("MINIMAP", "MINIMAP_DESC", "showMinimap", function() ns.UpdateMinimapButton() end)
OptionCheck("FULL_WIDTH", "FULL_WIDTH_DESC", "fullWidth")
OptionCheck("QUEST_XP", "QUEST_XP_DESC", "showQuestXP")
OptionCheck("NEWS_LOGIN", "NEWS_LOGIN_DESC", "newsOnLogin")
EndChecks()
cursorY = cursorY - 10

StartPage("PAGE_REP")
Section("SECTION_REPUTATION")
EndChecks()
OptionCheck("REP_BAR", "REP_BAR_DESC", "showRepBar")
OptionCheck("REP_SIDE", "REP_SIDE_DESC", "repSide")
OptionCheck("REP_HOVER", "REP_HOVER_DESC", "showRepHover")
OptionCheck("MAX_LEVEL_REP", "MAX_LEVEL_REP_DESC", "maxLevelRep")
OptionCheck("REP_ONLY", "REP_ONLY_DESC", "repOnly")
OptionCheck("REP_OWN_COLOR", "REP_OWN_COLOR_DESC", "repOwnColor")
EndChecks()
cursorY = cursorY - 10
CreateColorRow("REP_COLOR", "repColor")
cursorY = cursorY - 10

StartFooter()

-- Language: a drop-down list of every translation
local langLabel = footer:CreateFontString(nil, "OVERLAY")
langLabel:SetFontObject(FontSmall)
langLabel:SetTextColor(TEXT_LO[1], TEXT_LO[2], TEXT_LO[3])
langLabel:SetPoint("TOPLEFT", 0, cursorY)
Localize(langLabel, "LANGUAGE")

local function ApplyLanguage(lang)
    ns.SetLanguage(lang)
    ns.ApplyFonts()
    ns.ApplyBindingNames()
    for _, fs in ipairs(localizedTexts) do fs:SetText(T(fs.l10nKey)) end
    ns.Refresh()
    ns.RefreshOptions()
end

local LANG_WIDTH = 104
local langButton = MakeFlatButton(footer, LANG_WIDTH, 22)
langButton:SetPoint("TOPLEFT", 62, cursorY + 4)

local langArrow = langButton:CreateTexture(nil, "OVERLAY")
langArrow:SetSize(12, 12)
langArrow:SetPoint("RIGHT", -6, 0)
langArrow:SetTexture(WHITE)
langArrow:SetVertexColor(GOLD[1], GOLD[2], GOLD[3])
langArrow:SetRotation(math.rad(45))
langArrow:SetSize(7, 7)

-- The list itself, opened under the button. It belongs to UIParent, not to
-- the panel: a click on the panel raises it (SetToplevel) and it would
-- cover the list, eating the clicks.
local langList = CreateFrame("Frame", "MyXPBarLanguageList", UIParent, "BackdropTemplate")
langList:SetFrameStrata("FULLSCREEN_DIALOG")
langList:SetToplevel(true)
langList:SetBackdrop(BOX_BACKDROP)
langList:SetBackdropColor(CARD_BG[1], CARD_BG[2], CARD_BG[3], 0.98)
langList:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], 0.6)
langList:SetSize(LANG_WIDTH, 10 + #ns.LANGUAGES * 20)
-- No gap under the button: crossing it would close the list
langList:SetPoint("TOPLEFT", langButton, "BOTTOMLEFT", 0, 0)
langList:EnableMouse(true)
langList:Hide()

local langEntries = {}
for i, entry in ipairs(ns.LANGUAGES) do
    local item = CreateFrame("Button", nil, langList)
    item:SetSize(LANG_WIDTH - 10, 20)
    item:SetPoint("TOPLEFT", 5, -5 - (i - 1) * 20)

    item.highlight = item:CreateTexture(nil, "BACKGROUND")
    item.highlight:SetAllPoints()
    item.highlight:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.25)
    item.highlight:Hide()

    item.text = item:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    item.text:SetPoint("LEFT", 6, 0)
    item.text:SetText(entry.name)

    item.key = entry.key
    item:SetScript("OnEnter", function(self) self.highlight:Show() end)
    item:SetScript("OnLeave", function(self) self.highlight:Hide() end)
    item:SetScript("OnClick", function(self)
        langList:Hide()
        if ns.Language() == self.key then return end
        PlayUISound("IG_MAINMENU_OPTION_CHECKBOX_ON")
        ApplyLanguage(self.key)
    end)
    langEntries[i] = item
end

langButton:SetScript("OnClick", function()
    PlayUISound("IG_MAINMENU_OPTION_CHECKBOX_ON")
    langList:SetShown(not langList:IsShown())
end)
-- Closes a short moment after the mouse left both the button and the list,
-- so going from one to the other never closes it
local LANG_GRACE = 0.6
local langAway = 0
langList:SetScript("OnShow", function() langAway = 0 end)
langList:SetScript("OnUpdate", function(self, elapsed)
    if self:IsMouseOver(4, -4, -4, 4) or langButton:IsMouseOver(4, -4, -4, 4) then
        langAway = 0
        return
    end
    langAway = langAway + elapsed
    if langAway > LANG_GRACE then self:Hide() end
end)
panel:HookScript("OnHide", function() langList:Hide() end)

tinsert(refreshers, function()
    local current = ns.Language()
    langButton:SetText(ns.LanguageName(current))
    for _, item in ipairs(langEntries) do
        if item.key == current then
            item.text:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
        else
            item.text:SetTextColor(1, 1, 1)
        end
    end
end)

-- =========================================================
-- PROFILES
-- =========================================================
-- On the same row as the language: the menu is as tall as the screen allows.
-- Picking one gives it to this character; everything changed afterwards is
-- written in it, so there is nothing to save by hand.
local function ProfileChanged()
    ns.Refresh()
    ns.UpdateMinimapButton()
    ns.RefreshOptions()
end

local profileLabel = footer:CreateFontString(nil, "OVERLAY")
profileLabel:SetFontObject(FontSmall)
profileLabel:SetTextColor(TEXT_LO[1], TEXT_LO[2], TEXT_LO[3])
profileLabel:SetPoint("TOPLEFT", 182, cursorY)
Localize(profileLabel, "PROFILE")

local PROFILE_WIDTH = 118
local profileButton = MakeFlatButton(footer, PROFILE_WIDTH, 22)
profileButton:SetPoint("TOPLEFT", 232, cursorY + 4)
-- The tooltip also names the character the profile is given to
profileButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(T("PROFILE"))
    GameTooltip:AddLine(T("PROFILE_DESC"), 1, 1, 1, true)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(ns.Profiles.CharName(), GOLD[1], GOLD[2], GOLD[3])
    GameTooltip:Show()
end)
profileButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

local profileArrow = profileButton:CreateTexture(nil, "OVERLAY")
profileArrow:SetPoint("RIGHT", -6, 0)
profileArrow:SetTexture(WHITE)
profileArrow:SetVertexColor(GOLD[1], GOLD[2], GOLD[3])
profileArrow:SetRotation(math.rad(45))
profileArrow:SetSize(7, 7)

-- The list belongs to UIParent, not to the panel: a click on the panel
-- raises it (SetToplevel) and it would cover the list, eating the clicks.
local profileList = CreateFrame("Frame", "MyXPBarProfileList", UIParent, "BackdropTemplate")
profileList:SetFrameStrata("FULLSCREEN_DIALOG")
profileList:SetToplevel(true)
profileList:SetBackdrop(BOX_BACKDROP)
profileList:SetBackdropColor(CARD_BG[1], CARD_BG[2], CARD_BG[3], 0.98)
profileList:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], 0.6)
profileList:SetWidth(PROFILE_WIDTH)
profileList:SetPoint("TOPLEFT", profileButton, "BOTTOMLEFT", 0, 0)
profileList:EnableMouse(true)
profileList:Hide()

-- The profiles change while the menu is open, so the rows are built again
-- every time the list opens, and kept for the next time
local profileRows = {}
local function BuildProfileList()
    local names = ns.Profiles.List()
    local current = ns.Profiles.Current()
    for i, name in ipairs(names) do
        local row = profileRows[i]
        if not row then
            row = CreateFrame("Button", nil, profileList)
            row:SetSize(PROFILE_WIDTH - 10, 20)
            row:SetPoint("TOPLEFT", 5, -5 - (i - 1) * 20)
            row.highlight = row:CreateTexture(nil, "BACKGROUND")
            row.highlight:SetAllPoints()
            row.highlight:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.25)
            row.highlight:Hide()
            row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.text:SetPoint("LEFT", 6, 0)
            row.text:SetPoint("RIGHT", -6, 0)
            row.text:SetJustifyH("LEFT")
            row:SetScript("OnEnter", function(self) self.highlight:Show() end)
            row:SetScript("OnLeave", function(self) self.highlight:Hide() end)
            row:SetScript("OnClick", function(self)
                profileList:Hide()
                if self.value == ns.Profiles.Current() then return end
                PlayUISound("IG_MAINMENU_OPTION_CHECKBOX_ON")
                ns.Profiles.Use(self.value)
                ProfileChanged()
            end)
            profileRows[i] = row
        end
        row.value = name
        row.text:SetText(name)
        if name == current then
            row.text:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
        else
            row.text:SetTextColor(1, 1, 1)
        end
        row:Show()
    end
    for i = #names + 1, #profileRows do profileRows[i]:Hide() end
    profileList:SetHeight(10 + math.max(#names, 1) * 20)
end

profileButton:SetScript("OnClick", function()
    PlayUISound("IG_MAINMENU_OPTION_CHECKBOX_ON")
    if profileList:IsShown() then
        profileList:Hide()
        return
    end
    BuildProfileList()
    profileList:Show()
end)

-- Closes a short moment after the mouse left both the button and the list,
-- so going from one to the other never closes it
local profileAway = 0
profileList:SetScript("OnShow", function() profileAway = 0 end)
profileList:SetScript("OnUpdate", function(self, elapsed)
    if self:IsMouseOver(4, -4, -4, 4) or profileButton:IsMouseOver(4, -4, -4, 4) then
        profileAway = 0
        return
    end
    profileAway = profileAway + elapsed
    if profileAway > 0.6 then self:Hide() end
end)
panel:HookScript("OnHide", function() profileList:Hide() end)

-- A short message in the chat, for what the menu cannot show
local function ProfileMessage(key)
    local r, g, b = Accent()
    DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff%02x%02x%02xMyXPBar|r %s",
        math.floor(r * 255), math.floor(g * 255), math.floor(b * 255), T(key)))
end

-- The edit box of a popup, whichever name this client gives it
local function PopupEditBox(popup)
    if popup.editBox then return popup.editBox end
    if popup.GetEditBox then return popup:GetEditBox() end
    local name = popup.GetName and popup:GetName()
    return name and _G[name .. "EditBox"] or nil
end

local function CreateProfile(box)
    local wanted = box and box:GetText() or ""
    local name, reason = ns.Profiles.Create(wanted)
    if not name then
        ProfileMessage(reason)
        return
    end
    PlayUISound("IG_MAINMENU_OPTION_CHECKBOX_ON")
    ProfileChanged()
end

StaticPopupDialogs["MYXPBAR_NEW_PROFILE"] = {
    text = "%s",
    button1 = ACCEPT or "OK",
    button2 = CANCEL or "Cancel",
    hasEditBox = true,
    maxLetters = 20,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3, -- Away from the Blizzard popups that taint
    OnShow = function(self)
        local box = PopupEditBox(self)
        if box then
            box:SetText("")
            box:SetFocus()
        end
    end,
    OnAccept = function(self) CreateProfile(PopupEditBox(self)) end,
    EditBoxOnEnterPressed = function(self)
        local popup = self:GetParent()
        CreateProfile(self)
        popup:Hide()
    end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
}

-- The name is kept here rather than passed through the popup: the clients
-- do not all hand the same arguments to OnAccept
local deleting

StaticPopupDialogs["MYXPBAR_DELETE_PROFILE"] = {
    text = "%s",
    button1 = YES or ACCEPT or "OK",
    button2 = NO or CANCEL or "Cancel",
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
    OnAccept = function()
        if deleting and ns.Profiles.Delete(deleting) then
            PlayUISound("IG_MAINMENU_OPTION_CHECKBOX_OFF")
            ProfileChanged()
        end
        deleting = nil
    end,
    OnCancel = function() deleting = nil end,
}

local newProfileBtn = CreateButton(footer, "PROFILE_NEW", 76, 22, function()
    StaticPopup_Show("MYXPBAR_NEW_PROFILE", T("PROFILE_NEW_PROMPT"))
end)
newProfileBtn:SetPoint("TOPLEFT", 362, cursorY + 4)
Tip(newProfileBtn, "PROFILE_NEW", "PROFILE_NEW_DESC", "ANCHOR_TOP")

local deleteProfileBtn = CreateButton(footer, "PROFILE_DELETE", 76, 22, function()
    deleting = ns.Profiles.Current()
    StaticPopup_Show("MYXPBAR_DELETE_PROFILE", string.format(T("PROFILE_DELETE_PROMPT"), deleting))
end)
deleteProfileBtn:SetPoint("TOPLEFT", 446, cursorY + 4)
Tip(deleteProfileBtn, "PROFILE_DELETE", "PROFILE_DELETE_DESC", "ANCHOR_TOP")

tinsert(refreshers, function()
    profileButton:SetText(ns.Profiles.Current() or "?")
    -- The last profile cannot go: the addon would have nothing to read
    if ns.Profiles.Count() > 1 then
        deleteProfileBtn:Enable()
    else
        deleteProfileBtn:Disable()
    end
    if profileList:IsShown() then BuildProfileList() end
end)

cursorY = cursorY - 34

-- Footer
local footerLine = footer:CreateTexture(nil, "ARTWORK")
footerLine:SetHeight(1)
footerLine:SetColorTexture(1, 1, 1, 0.07)
footerLine:SetPoint("TOPLEFT", 0, cursorY)
footerLine:SetPoint("TOPRIGHT", footer, "TOPLEFT", FULL_W, cursorY)
cursorY = cursorY - 16

local BUTTON_Y = cursorY -- LayoutOptions places the row itself
local BUTTON_GAP = 8

local resetPosBtn = CreateButton(footer, "RESET_POSITION", 100, 26, function()
    ns.ResetPosition()
end)
local centerHorizontalBtn = CreateButton(footer, "CENTER_HORIZONTAL", 100, 26, function()
    ns.CenterPosition("horizontal")
end)
local centerVerticalBtn = CreateButton(footer, "CENTER_VERTICAL", 100, 26, function()
    ns.CenterPosition("vertical")
end)

local resetAllBtn = CreateButton(footer, "RESET_ALL", 100, 26, function()
    -- Only the profile in use: the other profiles and the language stay
    local angle = ns.db.minimap.angle
    for k in pairs(ns.db) do ns.db[k] = nil end
    ns.CopyDefaults(ns.defaults, ns.db)
    ns.db.minimap.angle = angle
    ns.Refresh()
    ns.UpdateMinimapButton()
    ns.RefreshOptions()
end)
local footerButtons = { resetPosBtn, resetAllBtn }
cursorY = cursorY - 70

local hint = footer:CreateFontString(nil, "OVERLAY")
hint:SetFontObject(FontSmall)
hint:SetTextColor(TEXT_LO[1], TEXT_LO[2], TEXT_LO[3])
hint:SetPoint("TOP", footer, "TOP", 0, cursorY)
hint:SetWidth(FULL_W)
Localize(hint, "HINT")
cursorY = cursorY - 36

local signature = footer:CreateFontString(nil, "OVERLAY")
signature:SetFontObject(FontSmall)
signature:SetTextColor(0.42, 0.43, 0.48)
signature:SetPoint("TOP", footer, "TOP", 0, cursorY)
signature:SetText(AUTHOR)

cursorY = cursorY - 26

FinishColumn()

-- =========================================================
-- THE LIST OF PAGES, DOWN THE LEFT SIDE
-- =========================================================
-- Two columns of widgets used to sit side by side, and every release made
-- the menu wider or taller. A page at a time keeps it the same size for
-- good, and says what is where.
local PAGE_ROW = 30

local sidebar = CreateFrame("Frame", nil, panel, "BackdropTemplate")
sidebar:SetSize(SIDE_W, 16 + #pages * PAGE_ROW)
sidebar:SetBackdrop(BOX_BACKDROP)
sidebar:SetBackdropColor(CARD_BG[1], CARD_BG[2], CARD_BG[3], 1)
sidebar:SetBackdropBorderColor(1, 1, 1, 0.09)

-- The area the pages are drawn on, a shade darker than the menu: a short
-- page then reads as a quiet area instead of cards floating in a hole
local contentPanel = CreateFrame("Frame", nil, panel, "BackdropTemplate")
contentPanel:SetBackdrop(BOX_BACKDROP)
contentPanel:SetBackdropColor(0.055, 0.058, 0.070, 1)
contentPanel:SetBackdropBorderColor(1, 1, 1, 0.07)
contentPanel:SetFrameLevel(math.max(panel:GetFrameLevel(), 1))

local function ShowPage(index)
    currentPage = index
    for i, page in ipairs(pages) do
        local on = (i == index)
        page.frame:SetShown(on)
        page.button.mark:SetShown(on)
        page.button.glow:SetAlpha(on and 0.22 or 0)
        page.button.text:SetTextColor(on and GOLD[1] or 0.85, on and GOLD[2] or 0.85,
            on and GOLD[3] or 0.85)
    end
end

for i, page in ipairs(pages) do
    local b = CreateFrame("Button", nil, sidebar)
    b:SetSize(SIDE_W - 16, PAGE_ROW - 4)
    b:SetPoint("TOPLEFT", 8, -8 - (i - 1) * PAGE_ROW)

    b.glow = b:CreateTexture(nil, "BACKGROUND")
    b.glow:SetAllPoints()
    b.glow:SetColorTexture(GOLD[1], GOLD[2], GOLD[3])
    b.glow:SetAlpha(0)

    -- The gold bar on the left of the page you are on
    b.mark = b:CreateTexture(nil, "ARTWORK")
    b.mark:SetColorTexture(GOLD[1], GOLD[2], GOLD[3])
    b.mark:SetWidth(3)
    b.mark:SetPoint("TOPLEFT", 0, -2)
    b.mark:SetPoint("BOTTOMLEFT", 0, 2)
    b.mark:Hide()

    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.text:SetPoint("LEFT", 12, 0)
    b.text:SetJustifyH("LEFT")
    b.text:SetWidth(SIDE_W - 32)
    Localize(b.text, page.key)

    b:SetScript("OnEnter", function(self)
        if currentPage ~= i then self.glow:SetAlpha(0.12) end
    end)
    b:SetScript("OnLeave", function(self)
        if currentPage ~= i then self.glow:SetAlpha(0) end
    end)
    b:SetScript("OnClick", function()
        if currentPage == i then return end
        PlayUISound("IG_MAINMENU_OPTION_CHECKBOX_ON")
        ShowPage(i)
    end)
    page.button = b
end

-- =========================================================
-- LAYOUT: the list on the left, the chosen page on the right
-- =========================================================
local GAP = 14 -- Between the pages and the footer

function ns.LayoutOptions()
    footer:ClearAllPoints()
    sidebar:ClearAllPoints()
    sidebar:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, CONTENT_TOP)

    local tallest = 0
    for _, page in ipairs(pages) do
        page.frame:ClearAllPoints()
        page.frame:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD + SIDE_W + GUTTER + CARD_PAD, CONTENT_TOP)
        tallest = math.max(tallest, page.frame:GetHeight())
    end
    ShowPage(currentPage)

    -- The menu is as tall as its tallest page: changing page moves nothing,
    -- and the list of pages runs all the way down beside it
    local contentHeight = math.max(tallest, 16 + #pages * PAGE_ROW)
    sidebar:SetHeight(contentHeight)
    contentPanel:ClearAllPoints()
    contentPanel:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD + SIDE_W + GUTTER, CONTENT_TOP)
    contentPanel:SetSize(CONTENT_W + CARD_PAD * 2, contentHeight)
    footer:SetWidth(FULL_W)
    footer:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, CONTENT_TOP - contentHeight - GAP)

    -- The buttons share the width of the menu, on one row
    local count = #footerButtons
    local buttonWidth = (FULL_W - BUTTON_GAP * (count - 1)) / count
    for i, button in ipairs(footerButtons) do
        button:SetWidth(buttonWidth)
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", footer, "TOPLEFT", (i - 1) * (buttonWidth + BUTTON_GAP), BUTTON_Y)
    end
    local centerWidth = (buttonWidth - BUTTON_GAP) / 2
    centerHorizontalBtn:SetWidth(centerWidth)
    centerVerticalBtn:SetWidth(centerWidth)
    centerHorizontalBtn:ClearAllPoints()
    centerVerticalBtn:ClearAllPoints()
    centerHorizontalBtn:SetPoint("TOPLEFT", resetPosBtn, "BOTTOMLEFT", 0, -BUTTON_GAP)
    centerVerticalBtn:SetPoint("TOPLEFT", centerHorizontalBtn, "TOPRIGHT", BUTTON_GAP, 0)

    panel:SetSize(PANEL_WIDTH,
        -CONTENT_TOP + contentHeight + GAP + footer:GetHeight() + 16)
end

-- =========================================================
-- OPEN / CLOSE
-- =========================================================
function ns.RefreshOptions()
    if not panel:IsShown() then return end
    for _, fn in ipairs(refreshers) do fn() end
    RefreshAccent()
end

panel:SetScript("OnShow", function()
    PlayUISound("IG_CHARACTER_INFO_OPEN")
    ns.previewing = true
    -- Texts may have been created before the saved language was loaded
    for _, fs in ipairs(localizedTexts) do fs:SetText(T(fs.l10nKey)) end
    ns.Refresh()
    ns.RefreshOptions()
end)
panel:SetScript("OnHide", function()
    PlayUISound("IG_CHARACTER_INFO_CLOSE")
    ns.previewing = false
    ns.Refresh()
end)

function ns.ToggleOptions()
    panel:SetShown(not panel:IsShown())
end

-- =========================================================
-- WHAT'S NEW
-- =========================================================
-- Shown once after an update, and on /mxp news. The lines are translated like
-- everything else: one key per line, rewritten with each release.
local NEWS_LINES = { "NEWS_1", "NEWS_2", "NEWS_3", "NEWS_4" }
local NEWS_W = 420

local news = CreateFrame("Frame", "MyXPBarNewsFrame", UIParent, "BackdropTemplate")
news:SetSize(NEWS_W, 200)
news:SetPoint("CENTER", 0, 60)
news:SetFrameStrata("DIALOG")
news:SetToplevel(true)
news:SetMovable(true)
news:SetClampedToScreen(true)
news:EnableMouse(true)
news:RegisterForDrag("LeftButton")
news:SetScript("OnDragStart", news.StartMoving)
news:SetScript("OnDragStop", news.StopMovingOrSizing)
news:SetBackdrop(DIALOG_BACKDROP)
news:SetBackdropColor(PANEL_BG[1], PANEL_BG[2], PANEL_BG[3], 0.97)
news:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], 0.5)
news:Hide()
tinsert(UISpecialFrames, "MyXPBarNewsFrame") -- Escape closes it

local newsGlow = news:CreateTexture(nil, "BACKGROUND", nil, 2)
newsGlow:SetPoint("TOPLEFT", 12, -12)
newsGlow:SetPoint("TOPRIGHT", -12, -12)
newsGlow:SetHeight(90)
SetGradientSafe(newsGlow, "VERTICAL", 0.55, 0.38, 0.1, 0, 0.3)

local newsIcon = news:CreateTexture(nil, "ARTWORK")
newsIcon:SetSize(32, 32)
newsIcon:SetPoint("TOPLEFT", 22, -20)
newsIcon:SetTexture(ICON)

local newsTitle = news:CreateFontString(nil, "OVERLAY")
newsTitle:SetFontObject(FontSection)
newsTitle:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
newsTitle:SetPoint("TOPLEFT", newsIcon, "TOPRIGHT", 10, -2)
Localize(newsTitle, "NEWS_TITLE")

local newsVersion = news:CreateFontString(nil, "OVERLAY")
newsVersion:SetFontObject(FontSmall)
newsVersion:SetTextColor(0.75, 0.68, 0.52)
newsVersion:SetPoint("TOPLEFT", newsTitle, "BOTTOMLEFT", 0, -3)
newsVersion:SetText("MyXPBar v" .. VERSION)

local newsCloseX = CreateFrame("Button", nil, news, "UIPanelCloseButton")
newsCloseX:SetPoint("TOPRIGHT", -6, -6)
newsCloseX:SetScript("OnClick", function() news:Hide() end)

local newsOrnament = Ornament(news, NEWS_W - 44)
local newsTexts = {}
for i, key in ipairs(NEWS_LINES) do
    local bullet = Diamond(news, 5, "OVERLAY")
    local line = news:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    line:SetWidth(NEWS_W - 70)
    line:SetJustifyH("LEFT")
    line:SetSpacing(2)
    Localize(line, key)
    newsTexts[i] = { bullet = bullet, text = line }
end

local newsClose = CreateButton(news, "NEWS_CLOSE", 140, 24, function() news:Hide() end)

-- The lines wrap, so the height is only known once they hold their text
local function LayoutNews()
    local y = -64
    newsOrnament:ClearAllPoints()
    newsOrnament:SetPoint("TOP", news, "TOP", 0, y)
    y = y - 16
    for _, entry in ipairs(newsTexts) do
        entry.text:ClearAllPoints()
        entry.text:SetPoint("TOPLEFT", news, "TOPLEFT", 42, y)
        entry.bullet:ClearAllPoints()
        entry.bullet:SetPoint("TOPLEFT", news, "TOPLEFT", 26, y - 5)
        y = y - math.max(entry.text:GetStringHeight(), 14) - 10
    end
    y = y - 6
    newsClose:ClearAllPoints()
    newsClose:SetPoint("TOP", news, "TOP", 0, y)
    news:SetHeight(-y + 24 + 16)
end

function ns.ShowNews()
    newsVersion:SetText("MyXPBar v" .. ns.AddonVersion())
    for _, entry in ipairs(newsTexts) do entry.text:SetText(T(entry.text.l10nKey)) end
    LayoutNews()
    news:Show()
    LayoutNews() -- The wrapped height is only final once it is on screen
    PlayUISound("IG_CHARACTER_INFO_OPEN")
end

-- One chat line after an update, and the panel unless the player is fighting
function ns.AnnounceNews(version)
    local r, g, b = Accent()
    DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff%02x%02x%02xMyXPBar|r %s",
        math.floor(r * 255), math.floor(g * 255), math.floor(b * 255),
        string.format(T("NEWS_CHAT"), version)))
    if not InCombatLockdown() then ns.ShowNews() end
end

-- =========================================================
-- SHOWING AND HIDING THE BAR
-- =========================================================
-- The same switch behind the option, /mxp on and off, the middle click on the
-- minimap button and the key binding.
function ns.SetBarEnabled(on, quiet)
    ns.db.enabled = on and true or false
    if not quiet then
        local r, g, b = Accent()
        DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff%02x%02x%02xMyXPBar|r %s",
            math.floor(r * 255), math.floor(g * 255), math.floor(b * 255),
            T(ns.db.enabled and "CHAT_BAR_ON" or "CHAT_BAR_OFF")))
    end
    ns.Refresh()
    ns.RefreshOptions()
end

-- Called by the key binding (see Bindings.xml)
function MyXPBar_ToggleBar()
    ns.SetBarEnabled(not ns.BarEnabled())
end

-- The key bindings window reads these globals when it opens, so they are set
-- again every time the language changes
function ns.ApplyBindingNames()
    BINDING_HEADER_MYXPBAR = "MyXPBar"
    BINDING_NAME_MYXPBAR_TOGGLE = T("BINDING_TOGGLE")
end

-- =========================================================
-- SLASH COMMANDS
-- =========================================================
SLASH_MYXPBAR1 = "/mxp"
SLASH_MYXPBAR2 = "/myxpbar"
SlashCmdList.MYXPBAR = function(msg)
    local command = strlower(strtrim(msg or ""))
    local function Print(line) DEFAULT_CHAT_FRAME:AddMessage("|cff9966ffMyXPBar|r " .. line) end
    if command == "debug" then
        -- Shows the state of the settings backup (Forever beta workaround)
        ns.Persist.Debug(Print)
    elseif command == "quests" then
        -- What the quest log gives on this client
        ns.DebugQuests(Print)
    elseif command == "news" then
        ns.ShowNews()
    elseif command == "on" or command == "off" then
        ns.SetBarEnabled(command == "on")
    else
        ns.ToggleOptions()
    end
end

-- Addon compartment (the addons button next to the minimap)
function MyXPBar_OnAddonCompartmentClick()
    ns.ToggleOptions()
end

-- =========================================================
-- MINIMAP BUTTON
-- =========================================================
local mm = CreateFrame("Button", "MyXPBarMinimapButton", Minimap)
mm:SetSize(31, 31)
mm:SetFrameStrata("MEDIUM")
mm:SetFrameLevel(8)
mm:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")
mm:RegisterForDrag("LeftButton")
mm:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

local mmBackground = mm:CreateTexture(nil, "BACKGROUND")
mmBackground:SetSize(24, 24)
mmBackground:SetPoint("CENTER")
mmBackground:SetTexture("Interface\\Minimap\\UI-Minimap-Background")

local mmIcon = mm:CreateTexture(nil, "ARTWORK")
mmIcon:SetSize(18, 18)
mmIcon:SetPoint("CENTER")
mmIcon:SetTexture(ICON)
MakeRound(mmIcon)

local mmBorder = mm:CreateTexture(nil, "OVERLAY")
mmBorder:SetSize(50, 50)
mmBorder:SetPoint("TOPLEFT")
mmBorder:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

local function UpdateMinimapPosition()
    local angle = math.rad(ns.db.minimap.angle)
    local radius = (Minimap:GetWidth() / 2) + 5
    mm:ClearAllPoints()
    mm:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

function ns.UpdateMinimapButton()
    mm:SetShown(ns.db.showMinimap)
    UpdateMinimapPosition()
end

mm:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
        local mx, my = Minimap:GetCenter()
        local px, py = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        ns.db.minimap.angle = math.deg(math.atan2(py / scale - my, px / scale - mx))
        UpdateMinimapPosition()
    end)
    GameTooltip:Hide()
end)
mm:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)

mm:SetScript("OnClick", function(self, button)
    if button == "MiddleButton" then
        MyXPBar_ToggleBar()
    elseif button == "RightButton" then
        ns.db.locked = not ns.db.locked
        local r, g, b = Accent()
        DEFAULT_CHAT_FRAME:AddMessage(
            string.format("|cff%02x%02x%02xMyXPBar|r : %s",
                math.floor(r * 255), math.floor(g * 255), math.floor(b * 255),
                T(ns.db.locked and "CHAT_LOCKED" or "CHAT_UNLOCKED")))
        ns.RefreshOptions()
    else
        ns.ToggleOptions()
    end
end)

mm:SetScript("OnEnter", function(self)
    local r, g, b = Accent()
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("MyXPBar", r, g, b)
    if ns.ShouldShowBar() then
        local cur, max = UnitXP("player"), UnitXPMax("player")
        local pct = max > 0 and (cur / max * 100) or 0
        GameTooltip:AddDoubleLine(T("TT_LEVEL") .. " " .. UnitLevel("player"), string.format("%.1f%%", pct), 1, 1, 1, 1, 1, 1)
        GameTooltip:AddDoubleLine(T("TT_XP"), ns.FormatNumber(cur) .. " / " .. ns.FormatNumber(max), 0.8, 0.8, 0.8, 1, 1, 1)
        local rested = GetXPExhaustion()
        if rested and max > 0 then
            GameTooltip:AddDoubleLine(T("TT_RESTED"), string.format("%.1f%%", rested / max * 100), 0.8, 0.8, 0.8, 0.4, 0.7, 1)
        end
    end
    GameTooltip:AddDoubleLine(T("PROFILE"), ns.Profiles.Current() or "?",
        0.8, 0.8, 0.8, GOLD[1], GOLD[2], GOLD[3])
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(T("TT_LEFT_CLICK"), 0.7, 0.7, 0.7)
    GameTooltip:AddLine(T("TT_RIGHT_CLICK"), 0.7, 0.7, 0.7)
    GameTooltip:AddLine(T("TT_MIDDLE_CLICK"), 0.7, 0.7, 0.7)
    GameTooltip:AddLine(T("TT_DRAG"), 0.7, 0.7, 0.7)
    GameTooltip:Show()
end)
mm:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- Place the button once the saved settings are loaded
tinsert(ns.dbReadyCallbacks, ns.UpdateMinimapButton)
-- The key binding carries the name of the saved language
tinsert(ns.dbReadyCallbacks, ns.ApplyBindingNames)
-- The saved language decides which title font can be used
tinsert(ns.dbReadyCallbacks, ns.ApplyFonts)
-- The saved layout (horizontal or vertical) is applied once settings load
tinsert(ns.dbReadyCallbacks, function() ns.LayoutOptions() end)
