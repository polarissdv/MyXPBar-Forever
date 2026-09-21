local ADDON_NAME, ns = ...
local T = ns.T

-- =========================================================
-- STYLE (native WoW look)
-- =========================================================
local VERSION = "2.7"
local PANEL_WIDTH = 420
local PAD = 26
local CONTENT_W = PANEL_WIDTH - PAD * 2
local WHITE = "Interface\\Buttons\\WHITE8x8"
local CIRCLE_MASK = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
local BAR_TEXTURE = "Interface\\TargetingFrame\\UI-StatusBar"
local FONT_GOTHIC = "Fonts\\MORPHEUS.TTF"
local ICON = "Interface\\AddOns\\MyXPBar\\Media\\icon"
local AUTHOR = "Made by Polarz141"

local GOLD = { 1, 0.82, 0.35 }

local DIALOG_BACKDROP = {
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
}
local BOX_BACKDROP = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
}

local function MakeFont(name, size, outline)
    local font = CreateFont(name)
    font:SetFont(FONT_GOTHIC, size, outline)
    font:SetShadowOffset(1, -1)
    font:SetShadowColor(0, 0, 0, 1)
    return font
end
local FontTitle = MakeFont("MyXPBarFontTitle", 30, "OUTLINE")
local FontSection = MakeFont("MyXPBarFontSection", 17, "OUTLINE")
local FontSmall = MakeFont("MyXPBarFontSmall", 13, "")

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
panel:Hide()
tinsert(UISpecialFrames, "MyXPBarOptionsFrame") -- Escape closes the menu

-- Warm light at the top of the panel
local topGlow = panel:CreateTexture(nil, "BACKGROUND", nil, 2)
topGlow:SetPoint("TOPLEFT", 12, -12)
topGlow:SetPoint("TOPRIGHT", -12, -12)
topGlow:SetHeight(120)
SetGradientSafe(topGlow, "VERTICAL", 0.55, 0.38, 0.1, 0, 0.3)

-- Header (drag to move the panel)
local header = CreateFrame("Frame", nil, panel)
header:SetPoint("TOPLEFT")
header:SetPoint("TOPRIGHT")
header:SetHeight(76)
header:EnableMouse(true)
header:SetScript("OnMouseDown", function() panel:StartMoving() end)
header:SetScript("OnMouseUp", function() panel:StopMovingOrSizing() end)

-- Addon icon in a gold frame, sitting on the top border
local crest = CreateFrame("Frame", nil, panel, "BackdropTemplate")
crest:SetSize(48, 48)
crest:SetPoint("CENTER", panel, "TOP", 0, -2)
crest:SetFrameLevel(panel:GetFrameLevel() + 10)
crest:SetBackdrop(BOX_BACKDROP)
crest:SetBackdropColor(0, 0, 0, 1)
crest:SetBackdropBorderColor(GOLD[1], GOLD[2], GOLD[3], 1)
local crestIcon = crest:CreateTexture(nil, "ARTWORK")
crestIcon:SetPoint("TOPLEFT", 5, -5)
crestIcon:SetPoint("BOTTOMRIGHT", -5, 5)
crestIcon:SetTexture(ICON)

local title = panel:CreateFontString(nil, "OVERLAY")
title:SetFontObject(FontTitle)
title:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
title:SetPoint("TOP", 0, -30)
title:SetText("MyXPBar")

local titleOrnament = Ornament(panel, 260)
titleOrnament:SetPoint("TOP", title, "BOTTOM", 0, -4)

local versionText = panel:CreateFontString(nil, "OVERLAY")
versionText:SetFontObject(FontSmall)
versionText:SetTextColor(0.75, 0.68, 0.52)
versionText:SetPoint("TOP", titleOrnament, "BOTTOM", 0, -4)
versionText:SetText("v" .. VERSION .. "  ·  Options")

local closeButton = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
closeButton:SetPoint("TOPRIGHT", -6, -6)

-- Vertical cursor used to stack widgets
local cursorY = -104

-- =========================================================
-- WIDGETS
-- =========================================================
local function Section(key)
    cursorY = cursorY - 8
    local label = panel:CreateFontString(nil, "OVERLAY")
    label:SetFontObject(FontSection)
    label:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    label:SetPoint("TOPLEFT", PAD, cursorY)
    Localize(label, key)

    local line = panel:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", label, "TOPRIGHT", 10, -9)
    line:SetPoint("TOPRIGHT", panel, "TOPLEFT", PANEL_WIDTH - PAD, cursorY - 9)
    SetGradientSafe(line, "HORIZONTAL", GOLD[1], GOLD[2], GOLD[3], 0.7, 0)

    cursorY = cursorY - 26
end

local function CreateSlider(key, minV, maxV, step, getValue, setValue, formatValue)
    local holder = CreateFrame("Frame", nil, panel)
    holder:SetSize(CONTENT_W, 42)
    holder:SetPoint("TOPLEFT", PAD, cursorY)
    cursorY = cursorY - 44

    local label = holder:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT")
    Localize(label, key)

    local valueText = holder:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    valueText:SetPoint("TOPRIGHT")

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

    -- Track: a thin engraved groove
    local track = slider:CreateTexture(nil, "BACKGROUND")
    track:SetColorTexture(0, 0, 0, 0.6)
    track:SetHeight(6)
    track:SetPoint("LEFT")
    track:SetPoint("RIGHT")
    local trackEdge = slider:CreateTexture(nil, "BORDER")
    trackEdge:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.25)
    trackEdge:SetHeight(1)
    trackEdge:SetPoint("BOTTOMLEFT", track, "BOTTOMLEFT", 0, -1)
    trackEdge:SetPoint("BOTTOMRIGHT", track, "BOTTOMRIGHT", 0, -1)

    local thumb = slider:CreateTexture(nil, "OVERLAY")
    thumb:SetTexture(WHITE)
    thumb:SetVertexColor(GOLD[1], GOLD[2], GOLD[3])
    thumb:SetSize(12, 12)
    MakeRound(thumb)
    slider:SetThumbTexture(thumb)

    local fill = slider:CreateTexture(nil, "ARTWORK")
    fill:SetHeight(6)
    fill:SetPoint("LEFT", track, "LEFT")
    fill:SetPoint("RIGHT", thumb, "CENTER")
    SetGradientSafe(fill, "HORIZONTAL", GOLD[1], GOLD[2], GOLD[3], 0.45, 0.95)

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
    slider:SetScript("OnEnter", function() thumb:SetSize(14, 14) end)
    slider:SetScript("OnLeave", function() thumb:SetSize(12, 12) end)

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
    local row = CreateFrame("Frame", nil, panel)
    row:SetSize(CONTENT_W, 26)
    row:SetPoint("TOPLEFT", PAD, cursorY)
    cursorY = cursorY - 34

    local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
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
        dot:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10 })
        dot:SetBackdropBorderColor(0.5, 0.42, 0.25, 1)

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
            self:SetBackdropBorderColor(self.selected and GOLD[1] or 0.5, self.selected and GOLD[2] or 0.42, self.selected and GOLD[3] or 0.25, 1)
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
    custom:SetBackdropColor(0, 0, 0, 1)
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
                dot:SetBackdropBorderColor(0.5, 0.42, 0.25, 1)
            end
        end
    end)
end

-- Blizzard checkboxes, two per row
local checkIndex = 0
local function CreateCheck(labelKey, descKey, getValue, setValue)
    local col = checkIndex % 2
    local check = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    check:SetSize(24, 24)
    check:SetPoint("TOPLEFT", PAD + col * (CONTENT_W / 2), cursorY)
    if col == 1 then cursorY = cursorY - 28 end
    checkIndex = checkIndex + 1

    local templateText = check.Text or check.text
    if templateText then templateText:SetText("") end

    local label = check:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("LEFT", check, "RIGHT", 2, 1)
    label:SetWidth(CONTENT_W / 2 - 30)
    label:SetJustifyH("LEFT")
    Localize(label, labelKey)

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
end

local function OptionCheck(labelKey, descKey, dbKey, onChange)
    CreateCheck(labelKey, descKey,
        function() return ns.db[dbKey] end,
        function(v)
            ns.db[dbKey] = v
            if onChange then onChange() end
        end)
end

local function CreateButton(parent, labelKey, width, height, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width, height)
    b:SetText(T(labelKey))
    local fs = b.Text or b.text or b:GetFontString()
    if fs then Localize(fs, labelKey) end
    b:SetScript("OnClick", function()
        PlayUISound("IG_MAINMENU_OPTION_CHECKBOX_ON")
        onClick()
    end)
    return b
end

-- =========================================================
-- CONTENT
-- =========================================================
Section("SECTION_PREVIEW")
local previewBox = CreateFrame("Frame", nil, panel, "BackdropTemplate")
previewBox:SetSize(CONTENT_W, 64)
previewBox:SetPoint("TOPLEFT", PAD, cursorY)
previewBox:SetBackdrop(BOX_BACKDROP)
previewBox:SetBackdropColor(0, 0, 0, 0.7)
previewBox:SetBackdropBorderColor(0.6, 0.5, 0.28, 1)
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
    local b = CreateButton(panel, style.key, CONTENT_W / 3 - 6, 24, function()
        ns.db.style = style.id
        ns.Refresh()
        ns.RefreshOptions()
    end)
    b:SetPoint("TOPLEFT", PAD + col * (CONTENT_W / 3), cursorY - row * 28)
    b.style = style.id
    styleButtons[i] = b
end
cursorY = cursorY - 62
tinsert(refreshers, function()
    for _, b in ipairs(styleButtons) do
        if b.style == ns.db.style then b:LockHighlight() else b:UnlockHighlight() end
    end
end)

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

Section("SECTION_COLORS")
CreateColorRow("XP_COLOR", "xpColor")
CreateColorRow("RESTED_COLOR", "restedColor")
CreateSlider("BG_OPACITY", 0, 100, 5,
    function() return math.floor(ns.db.bgAlpha * 100 + 0.5) end,
    function(v) ns.db.bgAlpha = v / 100; ns.Refresh(); RefreshPreview() end,
    function(v) return v .. " %" end)

Section("SECTION_OPTIONS")
OptionCheck("LOCK", "LOCK_DESC", "locked")
OptionCheck("HIDE_BLIZZARD", "HIDE_BLIZZARD_DESC", "hideBlizzard")
OptionCheck("SOUND", nil, "playSound")
OptionCheck("SHOW_TEXT", "SHOW_TEXT_DESC", "showText")
OptionCheck("SHOW_RESTED", "SHOW_RESTED_DESC", "showRestedText")
OptionCheck("SMOOTH", "SMOOTH_DESC", "smooth")
OptionCheck("SHOW_GAINS", "SHOW_GAINS_DESC", "showGains")
OptionCheck("MINIMAP", "MINIMAP_DESC", "showMinimap", function() ns.UpdateMinimapButton() end)
OptionCheck("FULL_WIDTH", "FULL_WIDTH_DESC", "fullWidth")
OptionCheck("REP_HOVER", "REP_HOVER_DESC", "showRepHover")
cursorY = cursorY - 34

-- Language (FR | EN)
local langLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
langLabel:SetPoint("TOPLEFT", PAD, cursorY)
Localize(langLabel, "LANGUAGE")

local function ApplyLanguage(lang)
    ns.db.language = lang
    for _, fs in ipairs(localizedTexts) do fs:SetText(T(fs.l10nKey)) end
    ns.Refresh()
    ns.RefreshOptions()
end

local langButtons = {}
for i, lang in ipairs(ns.LANGUAGES) do
    local b = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    b:SetSize(44, 22)
    b:SetPoint("TOPLEFT", PAD + 110 + (i - 1) * 48, cursorY + 4)
    b:SetText(string.upper(lang))
    b.lang = lang
    b:SetScript("OnClick", function()
        if ns.db.language == lang then return end
        PlayUISound("IG_MAINMENU_OPTION_CHECKBOX_ON")
        ApplyLanguage(lang)
    end)
    langButtons[i] = b
end
tinsert(refreshers, function()
    for _, b in ipairs(langButtons) do
        if b.lang == ns.db.language then b:LockHighlight() else b:UnlockHighlight() end
    end
end)
cursorY = cursorY - 34

-- Footer
local footerOrnament = Ornament(panel, CONTENT_W)
footerOrnament:SetPoint("TOP", panel, "TOP", 0, cursorY)
cursorY = cursorY - 18

local resetPosBtn = CreateButton(panel, "RESET_POSITION", CONTENT_W / 2 - 6, 26, function()
    ns.ResetPosition()
end)
resetPosBtn:SetPoint("TOPLEFT", PAD, cursorY)

local resetAllBtn = CreateButton(panel, "RESET_ALL", CONTENT_W / 2 - 6, 26, function()
    local language = ns.db.language
    local angle = ns.db.minimap.angle
    for k in pairs(ns.db) do ns.db[k] = nil end
    ns.CopyDefaults(ns.defaults, ns.db)
    ns.db.language = language
    ns.db.minimap.angle = angle
    ns.Refresh()
    ns.UpdateMinimapButton()
    ns.RefreshOptions()
end)
resetAllBtn:SetPoint("TOPRIGHT", -PAD, cursorY)
cursorY = cursorY - 36

local hint = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
hint:SetPoint("TOP", panel, "TOP", 0, cursorY)
hint:SetWidth(CONTENT_W)
Localize(hint, "HINT")
cursorY = cursorY - 36

local signature = panel:CreateFontString(nil, "OVERLAY")
signature:SetFontObject(FontSmall)
signature:SetTextColor(0.75, 0.62, 0.35)
signature:SetPoint("TOP", panel, "TOP", 0, cursorY)
signature:SetText(AUTHOR)
local sigLeft = Diamond(panel, 5, "OVERLAY")
sigLeft:SetPoint("RIGHT", signature, "LEFT", -8, 0)
local sigRight = Diamond(panel, 5, "OVERLAY")
sigRight:SetPoint("LEFT", signature, "RIGHT", 8, 0)
cursorY = cursorY - 26

panel:SetHeight(-cursorY)

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

SLASH_MYXPBAR1 = "/mxp"
SLASH_MYXPBAR2 = "/myxpbar"
SlashCmdList.MYXPBAR = function(msg)
    if strlower(strtrim(msg or "")) == "debug" then
        -- Shows the state of the settings backup (Forever beta workaround)
        ns.Persist.Debug(function(line) DEFAULT_CHAT_FRAME:AddMessage("|cff9966ffMyXPBar|r " .. line) end)
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
mm:RegisterForClicks("LeftButtonUp", "RightButtonUp")
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
    if button == "RightButton" then
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
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(T("TT_LEFT_CLICK"), 0.7, 0.7, 0.7)
    GameTooltip:AddLine(T("TT_RIGHT_CLICK"), 0.7, 0.7, 0.7)
    GameTooltip:AddLine(T("TT_DRAG"), 0.7, 0.7, 0.7)
    GameTooltip:Show()
end)
mm:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- Place the button once the saved settings are loaded
tinsert(ns.dbReadyCallbacks, ns.UpdateMinimapButton)
