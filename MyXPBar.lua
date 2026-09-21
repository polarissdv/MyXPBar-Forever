local ADDON_NAME, ns = ...

-- =========================================================
-- CONFIGURATION
-- =========================================================
-- Everything below can be changed in game: minimap button or /mxp
local BAR_TEXTURE = "Interface\\TargetingFrame\\UI-StatusBar"
local FALLBACK_MAX_LEVEL = 60 -- Only used if the game can't tell the real max level
local RESTED_ALPHA = 0.5

ns.defaults = {
    width = 500,
    height = 24,
    xpColor = { r = 0.6, g = 0.4, b = 1 },     -- PURPLE
    restedColor = { r = 0.2, g = 0.6, b = 1 }, -- BLUE
    bgAlpha = 0.6,
    hideBlizzard = true,
    playSound = true,
    locked = false,
    showText = true,
    showRestedText = true,
    smooth = true,     -- Animated bar fill
    showGains = true,  -- Floating "+245 XP"
    style = "classic", -- classic | gold | segments | thin | spark | restedbar
    fullWidth = false,   -- Stretch from one screen edge to the other (width is ignored)
    showRepHover = true, -- Mouse over the bar: tracked reputation
    point = { "CENTER", "CENTER", 0, -200 },
    showMinimap = true,
    minimap = { angle = 225 },
}

-- Blizzard frames that hold the default XP bar, depending on the client UI.
-- Only the ones that exist in the current client are touched.
local BLIZZARD_XP_FRAMES = {
    "MainStatusTrackingBarContainer", -- Modern client (WoW Forever / Retail)
    "MainMenuExpBar",                 -- Classic-style UI
    "ExhaustionTick",                 -- Classic-style rested marker
}

-- Variables for mob calculation
local lastXP = 0
local lastGain = 0

-- =========================================================
-- SAVED SETTINGS
-- =========================================================
local function CopyDefaults(src, dst)
    if type(dst) ~= "table" then dst = {} end
    for k, v in pairs(src) do
        if type(v) == "table" then
            dst[k] = CopyDefaults(v, dst[k])
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
    return dst
end
ns.CopyDefaults = CopyDefaults

-- Defaults until the saved variables are loaded
ns.db = CopyDefaults(ns.defaults, {})
ns.previewing = false -- true while the options menu is open
ns.dbReadyCallbacks = {}

-- =========================================================
-- HELPERS
-- =========================================================
local function IsMaxLevel()
    if IsPlayerAtEffectiveMaxLevel then
        return IsPlayerAtEffectiveMaxLevel()
    end
    local maxLevel = GetMaxLevelForPlayerExpansion and GetMaxLevelForPlayerExpansion() or FALLBACK_MAX_LEVEL
    return UnitLevel("player") >= maxLevel
end

local function ShouldShowBar()
    if IsXPUserDisabled and IsXPUserDisabled() then return false end
    return not IsMaxLevel()
end
ns.ShouldShowBar = ShouldShowBar

local function PlayXPSound()
    if not ns.db.playSound then return end
    if SOUNDKIT and SOUNDKIT.IG_QUEST_LIST_OPEN then
        PlaySound(SOUNDKIT.IG_QUEST_LIST_OPEN, "SFX")
    end
end

local function FormatNumber(n)
    if BreakUpLargeNumbers then return BreakUpLargeNumbers(n) end
    return tostring(n)
end
ns.FormatNumber = FormatNumber

-- =========================================================
-- BLIZZARD XP BAR HIDING
-- =========================================================
local hideBlizzard = false
local pendingAfterCombat = false
local hookedFrames = {}

local function ApplyBlizzardFrame(frame)
    if hideBlizzard then
        -- Alpha works even in combat; Hide() waits for combat to end to avoid taint
        frame:SetAlpha(0)
        if InCombatLockdown() then
            pendingAfterCombat = true
        else
            frame:Hide()
        end
    else
        frame:SetAlpha(1)
    end
end

local function UpdateBlizzardBar()
    local wantHidden = ns.db.hideBlizzard and ShouldShowBar()
    local changed = (wantHidden ~= hideBlizzard)
    hideBlizzard = wantHidden

    for _, name in ipairs(BLIZZARD_XP_FRAMES) do
        local frame = _G[name]
        if frame then
            if not hookedFrames[frame] then
                hookedFrames[frame] = true
                -- Blizzard re-shows the bar on many events: hide it again each time
                frame:HookScript("OnShow", function(self)
                    if hideBlizzard then ApplyBlizzardFrame(self) end
                end)
            end
            if hideBlizzard then
                ApplyBlizzardFrame(frame)
            elseif changed then
                -- Give the bar back to Blizzard (max level, or option turned off)
                frame:SetAlpha(1)
                if StatusTrackingBarManager and StatusTrackingBarManager.UpdateBarsShown then
                    StatusTrackingBarManager:UpdateBarsShown()
                elseif not InCombatLockdown() then
                    frame:Show()
                end
            end
        end
    end
end

-- =========================================================
-- FRAME CREATION
-- =========================================================
local mainFrame = CreateFrame("Frame", "MyXPBarFrame", UIParent)
mainFrame:SetSize(ns.db.width, ns.db.height)
mainFrame:SetPoint("CENTER", 0, -200)
mainFrame:EnableMouse(true)
mainFrame:SetMovable(true)
mainFrame:SetClampedToScreen(true)
ns.mainFrame = mainFrame

-- Dragging logic (Shift + Left Click, or free drag while the options menu is open)
mainFrame:RegisterForDrag("LeftButton")
mainFrame:SetScript("OnDragStart", function(self)
    if ns.db.locked then return end
    if IsShiftKeyDown() or ns.previewing then self:StartMoving() end
end)
mainFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    self:SetUserPlaced(false) -- Position is kept in our own settings
    local point, _, relPoint, x, y = self:GetPoint(1)
    ns.db.point = { point, relPoint, x, y }
    -- Full width: only the height changes, the sides snap back to the screen edges
    if ns.db.fullWidth then ns.ApplyLayout() end
end)

-- Black Background
local bg = mainFrame:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints(mainFrame)
bg:SetColorTexture(0, 0, 0, ns.db.bgAlpha)

-- =========================================================
-- BARS (XP AND RESTED)
-- =========================================================
-- XP Bar
local xpBar = CreateFrame("StatusBar", nil, mainFrame)
xpBar:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 0, 0)
xpBar:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", 0, 0)
xpBar:SetStatusBarTexture(BAR_TEXTURE)
xpBar:SetFrameLevel(mainFrame:GetFrameLevel() + 2)

-- Rested Bar (Background layer)
local restedBar = CreateFrame("StatusBar", nil, mainFrame)
restedBar:SetAllPoints(xpBar)
restedBar:SetStatusBarTexture(BAR_TEXTURE)
restedBar:SetFrameLevel(mainFrame:GetFrameLevel() + 1)

-- =========================================================
-- TEXT ELEMENTS
-- =========================================================
-- Level Text (Left)
local levelText = xpBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
levelText:SetPoint("LEFT", xpBar, "LEFT", 5, 0)
levelText:SetTextColor(1, 1, 1)

-- XP Values & Kills (Center)
local valueText = xpBar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
valueText:SetPoint("CENTER", xpBar, "CENTER", 0, 0)
valueText:SetTextColor(1, 1, 1)

-- Percentage (Right)
local pctText = xpBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
pctText:SetPoint("RIGHT", xpBar, "RIGHT", -5, 0)
pctText:SetTextColor(1, 1, 1)

-- Rested Info (Bottom)
local subText = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
subText:SetPoint("TOP", mainFrame, "BOTTOM", 0, -5)
subText:SetTextColor(0.8, 0.8, 0.8)

-- =========================================================
-- BAR STYLES
-- =========================================================
local WHITE = "Interface\\Buttons\\WHITE8x8"
local SEGMENT_COUNT = 20

-- Gold frame (style "gold")
local goldBorder = CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
goldBorder:SetPoint("TOPLEFT", -2, 2)
goldBorder:SetPoint("BOTTOMRIGHT", 2, -2)
goldBorder:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12 })
goldBorder:SetBackdropBorderColor(0.85, 0.68, 0.3, 1)
goldBorder:Hide()

-- Shine on the upper half (style "gold")
local gloss = xpBar:CreateTexture(nil, "OVERLAY")
gloss:SetTexture(WHITE)
local okGloss = CreateColor and pcall(gloss.SetGradient, gloss, "VERTICAL",
    CreateColor(1, 1, 1, 0), CreateColor(1, 1, 1, 0.18))
if not okGloss then gloss:SetVertexColor(1, 1, 1, 0.08) end
gloss:Hide()

-- Separators (style "segments")
local segments = {}
for i = 1, SEGMENT_COUNT - 1 do
    local seg = xpBar:CreateTexture(nil, "OVERLAY")
    seg:SetColorTexture(0, 0, 0, 0.8)
    seg:SetWidth(2)
    seg:Hide()
    segments[i] = seg
end

-- Glowing edge (style "spark")
local spark = mainFrame:CreateTexture(nil, "OVERLAY")
spark:SetTexture(WHITE)
spark:SetBlendMode("ADD")
spark:SetWidth(8)
spark:Hide()

-- Separate rested bar under the main one (style "restedbar")
local underRested = CreateFrame("StatusBar", nil, mainFrame)
underRested:SetStatusBarTexture(BAR_TEXTURE)
underRested:SetPoint("TOPLEFT", mainFrame, "BOTTOMLEFT", 0, -2)
underRested:SetPoint("TOPRIGHT", mainFrame, "BOTTOMRIGHT", 0, -2)
underRested:SetHeight(4)
underRested:Hide()
local underBg = underRested:CreateTexture(nil, "BACKGROUND")
underBg:SetAllPoints()

local function UpdateSpark(fraction)
    if not spark:IsShown() then return end
    local width = xpBar:GetWidth()
    if not width or width <= 0 then return end
    spark:ClearAllPoints()
    spark:SetPoint("CENTER", xpBar, "LEFT", math.max(0, math.min(fraction, 1)) * width, 0)
end

-- =========================================================
-- REPUTATION ON HOVER
-- =========================================================
-- Covers the XP bar while the mouse is over it
local repBar = CreateFrame("StatusBar", nil, mainFrame)
repBar:SetAllPoints(xpBar)
repBar:SetStatusBarTexture(BAR_TEXTURE)
repBar:SetFrameLevel(xpBar:GetFrameLevel() + 3)
repBar:Hide()

local repBg = repBar:CreateTexture(nil, "BACKGROUND")
repBg:SetAllPoints()
repBg:SetColorTexture(0, 0, 0, 1) -- Opaque: the XP bar must not show through

local repName = repBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
repName:SetTextColor(1, 1, 1)
local repValue = repBar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
repValue:SetTextColor(1, 1, 1)
local repStanding = repBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
repStanding:SetTextColor(1, 1, 1)

-- name, standing (1-8), bar min, bar max, value, or nil when nothing is tracked
local function GetWatchedReputation()
    if C_Reputation and C_Reputation.GetWatchedFactionData then
        local data = C_Reputation.GetWatchedFactionData()
        if data and data.name then
            return data.name, data.reaction, data.currentReactionThreshold,
                data.nextReactionThreshold, data.currentStanding
        end
        return nil
    end
    if GetWatchedFactionInfo then
        local name, standing, barMin, barMax, value = GetWatchedFactionInfo()
        if name then return name, standing, barMin, barMax, value end
    end
    return nil
end

-- Returns false when no reputation is tracked
local function UpdateRepBar()
    local name, standing, barMin, barMax, value = GetWatchedReputation()
    if not name then return false end
    local max = math.max(barMax - barMin, 1)
    local current = math.max(value - barMin, 0)
    repBar:SetMinMaxValues(0, max)
    repBar:SetValue(current)

    local color = FACTION_BAR_COLORS and FACTION_BAR_COLORS[standing]
    if color then
        repBar:SetStatusBarColor(color.r, color.g, color.b, 1)
    else
        repBar:SetStatusBarColor(0, 0.6, 0.1, 1)
    end
    repName:SetText(name)
    repValue:SetText(FormatNumber(current) .. " / " .. FormatNumber(max))
    local label = _G["FACTION_STANDING_LABEL" .. tostring(standing)] or ""
    repStanding:SetText(string.format("%s  %.1f%%", label, current / max * 100))
    return true
end

local function SetXPTextsShown(show)
    levelText:SetShown(show)
    valueText:SetShown(show)
    pctText:SetShown(show)
end

local function ShowReputation()
    if not ns.db.showRepHover then return end
    if UpdateRepBar() then
        repBar:Show()
        SetXPTextsShown(false)
    else
        GameTooltip:SetOwner(mainFrame, "ANCHOR_TOP")
        GameTooltip:SetText(ns.T("REP_NONE"))
        GameTooltip:AddLine(ns.T("REP_NONE_DESC"), 1, 1, 1, true)
        GameTooltip:Show()
    end
end

local function HideReputation()
    if repBar:IsShown() then
        repBar:Hide()
        SetXPTextsShown(ns.db.showText)
    end
    if GameTooltip:IsOwned(mainFrame) then GameTooltip:Hide() end
end

mainFrame:SetScript("OnEnter", ShowReputation)
mainFrame:SetScript("OnLeave", HideReputation)
mainFrame:HookScript("OnDragStart", HideReputation)

-- =========================================================
-- APPLY SETTINGS
-- =========================================================
function ns.ApplyLayout()
    local db = ns.db
    local style = db.style or "classic"
    mainFrame:SetSize(db.width, db.height)

    local p = db.point
    mainFrame:ClearAllPoints()
    mainFrame:SetPoint(p[1], UIParent, p[2], p[3], p[4])

    -- Full width: keep the saved height on screen, pin both sides to the
    -- screen edges (follows resolution and UI scale changes by itself)
    local width = db.width
    if db.fullWidth then
        local bottom = mainFrame:GetBottom()
        if bottom then
            mainFrame:ClearAllPoints()
            mainFrame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, bottom)
            mainFrame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 0, bottom)
        end
        width = UIParent:GetWidth()
    end

    -- Bar geometry: thin keeps a slim bar at the bottom, gold insets it for the frame
    xpBar:ClearAllPoints()
    if style == "thin" then
        local barHeight = math.min(6, db.height)
        xpBar:SetPoint("BOTTOMLEFT", 0, 0)
        xpBar:SetPoint("BOTTOMRIGHT", 0, 0)
        xpBar:SetHeight(barHeight)
    elseif style == "gold" then
        xpBar:SetPoint("TOPLEFT", 2, -2)
        xpBar:SetPoint("BOTTOMRIGHT", -2, 2)
    else
        xpBar:SetPoint("TOPLEFT", 0, 0)
        xpBar:SetPoint("BOTTOMRIGHT", 0, 0)
    end
    restedBar:SetAllPoints(xpBar)
    bg:ClearAllPoints()
    bg:SetAllPoints(xpBar)
    bg:SetColorTexture(0, 0, 0, db.bgAlpha)

    -- Texts: inside the bar, or above it for the thin style
    levelText:ClearAllPoints()
    valueText:ClearAllPoints()
    pctText:ClearAllPoints()
    if style == "thin" then
        levelText:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 2, 0)
        valueText:SetPoint("TOP", mainFrame, "TOP", 0, 0)
        pctText:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -2, 0)
    else
        levelText:SetPoint("LEFT", xpBar, "LEFT", 5, 0)
        valueText:SetPoint("CENTER", xpBar, "CENTER", 0, 0)
        pctText:SetPoint("RIGHT", xpBar, "RIGHT", -5, 0)
    end

    local c = db.xpColor
    xpBar:SetStatusBarColor(c.r, c.g, c.b, 1)
    local rc = db.restedColor
    restedBar:SetStatusBarColor(rc.r, rc.g, rc.b, RESTED_ALPHA)
    underRested:SetStatusBarColor(rc.r, rc.g, rc.b, 1)
    underBg:SetColorTexture(0, 0, 0, db.bgAlpha)
    spark:SetVertexColor(math.min(c.r + 0.4, 1), math.min(c.g + 0.4, 1), math.min(c.b + 0.4, 1), 0.9)

    -- Style decorations
    goldBorder:SetShown(style == "gold")
    gloss:SetShown(style == "gold")
    if style == "gold" then
        gloss:ClearAllPoints()
        gloss:SetPoint("TOPLEFT", xpBar, "TOPLEFT")
        gloss:SetPoint("TOPRIGHT", xpBar, "TOPRIGHT")
        gloss:SetHeight(math.max(db.height / 2 - 2, 2))
    end

    local barWidth = (style == "gold") and (width - 4) or width
    for i, seg in ipairs(segments) do
        seg:SetShown(style == "segments")
        if style == "segments" then
            seg:ClearAllPoints()
            seg:SetPoint("TOP", xpBar, "TOPLEFT", barWidth * i / SEGMENT_COUNT, 0)
            seg:SetPoint("BOTTOM", xpBar, "BOTTOMLEFT", barWidth * i / SEGMENT_COUNT, 0)
        end
    end

    spark:SetShown(style == "spark")
    if style == "spark" then
        spark:SetHeight(db.height + 8)
    end

    -- The rested layer lives either on top of the bar, or in its own strip
    restedBar:SetShown(style ~= "restedbar")
    underRested:SetShown(style == "restedbar")

    subText:ClearAllPoints()
    if style == "restedbar" then
        subText:SetPoint("TOP", underRested, "BOTTOM", 0, -3)
    else
        subText:SetPoint("TOP", mainFrame, "BOTTOM", 0, -5)
    end

    -- Reputation texts sit exactly where the XP texts are
    repName:ClearAllPoints()
    repName:SetPoint(levelText:GetPoint())
    repValue:ClearAllPoints()
    repValue:SetPoint(valueText:GetPoint())
    repStanding:ClearAllPoints()
    repStanding:SetPoint(pctText:GetPoint())

    SetXPTextsShown(db.showText and not repBar:IsShown())
    subText:SetShown(db.showRestedText)
end

-- =========================================================
-- ANIMATION (smooth fill, floating XP gains, level up flash)
-- =========================================================
local ANIM_SPEED = 9      -- Higher = faster fill
local GAIN_TIME = 1.4     -- Seconds a "+XP" text stays on screen
local FLASH_TIME = 0.5

local anim = { value = 0, target = 0, rested = 0, restedTarget = 0, max = 1 }

-- The bar animates itself, and stops as soon as it reached its target
local function AnimateBars(self, elapsed)
    local step = math.min(elapsed * ANIM_SPEED, 1)
    anim.value = anim.value + (anim.target - anim.value) * step
    anim.rested = anim.rested + (anim.restedTarget - anim.rested) * step

    if math.abs(anim.target - anim.value) < 1 and math.abs(anim.restedTarget - anim.rested) < 1 then
        anim.value, anim.rested = anim.target, anim.restedTarget
        self:SetScript("OnUpdate", nil) -- Idle again: no work at all
    end
    xpBar:SetValue(anim.value)
    restedBar:SetValue(anim.rested)
    underRested:SetValue(anim.rested)
    UpdateSpark(anim.value / anim.max)
end

local function SetBarValues(current, restedTotal, maxXP, instant)
    xpBar:SetMinMaxValues(0, maxXP)
    restedBar:SetMinMaxValues(0, maxXP)
    underRested:SetMinMaxValues(0, maxXP)
    anim.target, anim.restedTarget, anim.max = current, restedTotal, maxXP

    if instant or not ns.db.smooth then
        anim.value, anim.rested = current, restedTotal
        xpBar:SetValue(current)
        restedBar:SetValue(restedTotal)
        underRested:SetValue(restedTotal)
        UpdateSpark(current / maxXP)
        mainFrame:SetScript("OnUpdate", nil)
    else
        mainFrame:SetScript("OnUpdate", AnimateBars)
    end
end

-- Floating "+245 XP" and level up flash share one driver
local flash = mainFrame:CreateTexture(nil, "OVERLAY")
flash:SetAllPoints(mainFrame)
flash:SetColorTexture(1, 1, 1, 1)
flash:SetBlendMode("ADD")
flash:Hide()

local effects = CreateFrame("Frame", nil, mainFrame)
local gainTexts = {}
local flashLeft = 0

local function EffectsUpdate(self, elapsed)
    local busy = false

    for _, fs in ipairs(gainTexts) do
        if fs.left then
            fs.left = fs.left - elapsed
            if fs.left <= 0 then
                fs.left = nil
                fs:Hide()
            else
                local progress = 1 - fs.left / GAIN_TIME
                fs:SetPoint("BOTTOM", mainFrame, "TOP", fs.offsetX, 4 + progress * 26)
                fs:SetAlpha(1 - progress * progress)
                busy = true
            end
        end
    end

    if flashLeft > 0 then
        flashLeft = flashLeft - elapsed
        flash:SetAlpha(math.max(flashLeft, 0) / FLASH_TIME * 0.5)
        if flashLeft <= 0 then flash:Hide() else busy = true end
    end

    if not busy then self:SetScript("OnUpdate", nil) end
end

local function ShowGain(amount)
    if not ns.db.showGains then return end
    local fs
    for _, candidate in ipairs(gainTexts) do
        if not candidate.left then fs = candidate break end
    end
    if not fs then
        fs = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        tinsert(gainTexts, fs)
    end
    local c = ns.db.xpColor
    fs:SetTextColor(c.r, c.g, c.b)
    fs:SetText("+" .. FormatNumber(amount) .. " XP")
    fs.offsetX = math.random(-30, 30)
    fs.left = GAIN_TIME
    fs:ClearAllPoints()
    fs:SetPoint("BOTTOM", mainFrame, "TOP", fs.offsetX, 4)
    fs:SetAlpha(1)
    fs:Show()
    effects:SetScript("OnUpdate", EffectsUpdate)
end

local function ShowLevelFlash()
    flashLeft = FLASH_TIME
    flash:SetAlpha(0.5)
    flash:Show()
    effects:SetScript("OnUpdate", EffectsUpdate)
end

-- =========================================================
-- LOGIC AND UPDATES
-- =========================================================
-- Only touch a font string when its text really changed
local shown = {}
local function SetTextCached(fontString, key, text)
    if shown[key] ~= text then
        shown[key] = text
        fontString:SetText(text)
    end
end

local lastLevel

local function UpdateStatus()
    UpdateBlizzardBar()

    -- 1. Check Max Level (Hide bar at max level or if XP is disabled)
    if not ShouldShowBar() and not ns.previewing then
        mainFrame:Hide()
        mainFrame:SetScript("OnUpdate", nil) -- Nothing to animate while hidden
        return -- Stop function execution here
    else
        mainFrame:Show()
    end

    local level = UnitLevel("player")
    local currXP = UnitXP("player")
    local maxXP = math.max(UnitXPMax("player"), 1)
    local rested = GetXPExhaustion() or 0

    -- 2. Calculate XP Gain and Play Sound
    local levelChanged = (lastLevel ~= nil and level ~= lastLevel)
    lastLevel = level

    local diff = currXP - lastXP
    if diff > 0 and not levelChanged then
        lastGain = diff
        PlayXPSound()
        ShowGain(diff)
    elseif levelChanged then
        ShowLevelFlash()
    end
    -- diff < 0: player probably leveled up (XP reset), keep last known estimation
    lastXP = currXP

    -- 3. Visual update of bars
    SetBarValues(currXP, math.min(currXP + rested, maxXP), maxXP, levelChanged)

    -- 4. Update Texts
    SetTextCached(levelText, "level", ns.T("BAR_LEVEL") .. " " .. level)

    -- Calculate remaining mobs
    local remainingXP = maxXP - currXP
    local mobsLeftText = ""

    if lastGain > 0 then
        local mobsCount = math.ceil(remainingXP / lastGain)
        -- If number is huge (bug or fresh start), don't show it yet
        if mobsCount < 10000 then
            mobsLeftText = string.format(" (%d %s)", mobsCount, ns.T("BAR_MOBS"))
        end
    end

    SetTextCached(valueText, "value", FormatNumber(currXP) .. " / " .. FormatNumber(maxXP) .. mobsLeftText)

    -- Percentage Calculation
    local pct = 0
    if maxXP > 0 then pct = (currXP / maxXP) * 100 end
    local totalString = string.format("%.1f%%", pct)

    -- Add projected rested percentage in parentheses
    if rested > 0 and maxXP > 0 then
        local restedPct = (rested / maxXP) * 100
        local projected = pct + restedPct
        if projected > 100 then projected = 100 end
        totalString = totalString .. string.format(" (%.1f%%)", projected)

        -- Bottom text update
        SetTextCached(subText, "sub", string.format("%s: %.1f%%", ns.T("BAR_RESTED"), restedPct))
    else
        SetTextCached(subText, "sub", "")
    end

    SetTextCached(pctText, "pct", totalString)
end

-- Several events fire together (XP gain + rested update): redraw only once
local updatePending = false
local function RequestUpdate(instant)
    if instant then
        updatePending = false
        UpdateStatus()
        return
    end
    if updatePending then return end
    updatePending = true
    C_Timer.After(0.05, function()
        updatePending = false
        UpdateStatus()
    end)
end

-- Re-apply every setting and redraw (used by the options menu)
function ns.Refresh()
    ns.ApplyLayout()
    wipe(shown) -- Language or options changed: every text must be redrawn
    UpdateStatus()
end

function ns.ResetPosition()
    ns.db.point = { unpack(ns.defaults.point) }
    ns.Refresh()
end

-- =========================================================
-- COMPACT SETTINGS (macro copy, see Persist.lua)
-- =========================================================
-- One line, fields in a fixed order, separated by ";" ("|" is an escape
-- character in WoW texts). Around 90 characters, a macro holds 255.
local SETTINGS_VERSION = "1"
local FLAG_FIELDS = {
    "locked", "hideBlizzard", "playSound", "showText",
    "showRestedText", "smooth", "showGains", "showMinimap",
    "fullWidth", "showRepHover", -- 2.7: missing in older copies, defaults apply
}

local function ColorToHex(c)
    return string.format("%02x%02x%02x",
        math.floor(c.r * 255 + 0.5), math.floor(c.g * 255 + 0.5), math.floor(c.b * 255 + 0.5))
end

local function HexToColor(hex)
    if not hex or not hex:match("^%x%x%x%x%x%x$") then return nil end
    return {
        r = tonumber(hex:sub(1, 2), 16) / 255,
        g = tonumber(hex:sub(3, 4), 16) / 255,
        b = tonumber(hex:sub(5, 6), 16) / 255,
    }
end

local function EncodeSettings(db)
    local flags = {}
    for i, key in ipairs(FLAG_FIELDS) do flags[i] = db[key] and "1" or "0" end
    local p = db.point
    return table.concat({
        SETTINGS_VERSION,
        string.format("%d", db._savedAt or time()),
        p[1], p[2], string.format("%.1f", p[3]), string.format("%.1f", p[4]),
        string.format("%d", math.floor(db.width + 0.5)),
        string.format("%d", math.floor(db.height + 0.5)),
        ColorToHex(db.xpColor), ColorToHex(db.restedColor),
        string.format("%d", math.floor(db.bgAlpha * 100 + 0.5)),
        db.style,
        table.concat(flags),
        string.format("%d", math.floor(db.minimap.angle + 0.5)),
        db.language or "",
    }, ";")
end

-- Returns a settings table, or nil if anything looks wrong
local function DecodeSettings(data)
    local f = { strsplit(";", data) }
    if f[1] ~= SETTINGS_VERSION or #f < 15 then return nil end

    local x, y = tonumber(f[5]), tonumber(f[6])
    local width, height = tonumber(f[7]), tonumber(f[8])
    local xpColor, restedColor = HexToColor(f[9]), HexToColor(f[10])
    local alpha, angle = tonumber(f[11]), tonumber(f[14])
    local anchor = "^%u+$"
    if not (x and y and width and height and xpColor and restedColor and alpha and angle)
        or not f[3]:match(anchor) or not f[4]:match(anchor)
        or not f[12]:match("^%a+$") or not f[13]:match("^[01]+$") then
        return nil
    end

    local settings = {
        _savedAt = tonumber(f[2]),
        point = { f[3], f[4], x, y },
        width = width,
        height = height,
        xpColor = xpColor,
        restedColor = restedColor,
        bgAlpha = alpha / 100,
        style = f[12],
        minimap = { angle = angle },
        language = f[15] ~= "" and f[15] or nil,
    }
    for i, key in ipairs(FLAG_FIELDS) do
        local bit = f[13]:sub(i, i)
        if bit ~= "" then settings[key] = (bit == "1") end
    end
    return settings
end

-- =========================================================
-- EVENTS
-- =========================================================
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_XP_UPDATE")
eventFrame:RegisterEvent("PLAYER_LEVEL_UP")
eventFrame:RegisterEvent("UPDATE_EXHAUSTION")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("ENABLE_XP_GAIN")
eventFrame:RegisterEvent("DISABLE_XP_GAIN")
eventFrame:RegisterEvent("UPDATE_FACTION")
eventFrame:RegisterEvent("DISPLAY_SIZE_CHANGED")
eventFrame:RegisterEvent("UI_SCALE_CHANGED")

eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON_NAME then return end
        self:UnregisterEvent("ADDON_LOADED")
        MyXPBarDB = CopyDefaults(ns.defaults, MyXPBarDB)
        ns.db = MyXPBarDB
        if not ns.db.language then ns.db.language = ns.DefaultLanguage() end
        ns.ApplyLayout()
        for _, callback in ipairs(ns.dbReadyCallbacks) do callback() end

        -- Forever beta: after a relog the settings come back from the CVar
        -- copy, after a restart from the macro copy
        ns.Persist.Register("MyXPBarDB", function() return MyXPBarDB end, function(saved)
            ns.Persist.Replace(MyXPBarDB, saved, ns.defaults)
            if not ns.db.language then ns.db.language = ns.DefaultLanguage() end
            ns.Refresh()
            for _, callback in ipairs(ns.dbReadyCallbacks) do callback() end
            if ns.RefreshOptions then ns.RefreshOptions() end
        end, { name = "MyXPBar", encode = EncodeSettings, decode = DecodeSettings })
        return
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Reset XP memory on login to avoid calculation bugs
        lastXP = UnitXP("player")
        lastLevel = UnitLevel("player")
        RequestUpdate(true) -- No animation on login
        return
    elseif event == "UPDATE_FACTION" then
        if repBar:IsShown() and not UpdateRepBar() then HideReputation() end
        return
    elseif event == "DISPLAY_SIZE_CHANGED" or event == "UI_SCALE_CHANGED" then
        -- Full width segments are placed from the bar width
        if ns.db.fullWidth then ns.ApplyLayout() end
        return
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Finish hiding the Blizzard bar that was faded out during combat
        if not pendingAfterCombat then return end
        pendingAfterCombat = false
    end
    RequestUpdate()
end)
