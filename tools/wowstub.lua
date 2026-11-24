-- A fake WoW client, just rich enough to load the addon outside the game.
-- It is not a simulator: frames remember their points, size, scripts and
-- children, and answer anything else with themselves, so a chain of calls
-- never stops the run. Enough to catch what compiling cannot: a nil call,
-- a handler that errors, a widget anchored to nothing.
--
--   lua tools/simulate.lua        (see that file)

local stub = {}

local frames = {}
stub.frames = frames

local FrameMT = {}

local function NewFrame(frameType, name, parent)
    local f = setmetatable({}, FrameMT)
    f.__type = frameType or "Frame"
    f.__name = name
    f.__parent = parent
    f.__scripts = {}
    f.__points = {}
    f.__children = {}
    f.__shown = true
    f.__width, f.__height = 0, 0
    f.__level = parent and ((parent.__level or 0) + 1) or 1
    f.__checked = false
    f.__text = ""
    if parent and parent.__children then table.insert(parent.__children, f) end
    table.insert(frames, f)
    if name then _G[name] = f end
    return f
end
stub.NewFrame = NewFrame

-- Methods the addon reads an answer from. Everything else is swallowed.
local real = {}

function real:SetScript(script, handler) self.__scripts[script] = handler end
function real:HookScript(script, handler)
    local previous = self.__scripts[script]
    self.__scripts[script] = function(...)
        if previous then previous(...) end
        return handler(...)
    end
end
function real:GetScript(script) return self.__scripts[script] end
function real:Show() self.__shown = true end
function real:Hide() self.__shown = false end
function real:SetShown(value) self.__shown = value and true or false end
function real:IsShown() return self.__shown end
function real:IsVisible() return self.__shown end
function real:IsMouseOver() return false end
function real:SetWidth(w) self.__width = w end
function real:SetHeight(h) self.__height = h end
function real:SetSize(w, h) self.__width, self.__height = w, h end
function real:GetWidth() return self.__width end
function real:GetHeight() return self.__height end
function real:GetSize() return self.__width, self.__height end
function real:SetPoint(...) table.insert(self.__points, { ... }) end
function real:ClearAllPoints() self.__points = {} end
function real:GetPoint(index)
    local p = self.__points[index or 1]
    if not p then return nil end
    return p[1], p[2], p[3], p[4], p[5]
end
function real:GetNumPoints() return #self.__points end
function real:SetFrameLevel(level) self.__level = level end
function real:GetFrameLevel() return self.__level or 1 end
function real:GetParent() return self.__parent end
function real:GetName() return self.__name end
function real:SetText(text) self.__text = text end
function real:GetText() return self.__text end
function real:GetStringHeight() return 12 end
function real:GetStringWidth() return 60 end
function real:SetChecked(value) self.__checked = value and true or false end
function real:GetChecked() return self.__checked end
function real:SetValue(value) self.__value = value end
function real:GetValue() return self.__value or 0 end
function real:SetMinMaxValues(a, b) self.__min, self.__max = a, b end
function real:GetMinMaxValues() return self.__min or 0, self.__max or 1 end
function real:GetCenter() return 400, 300 end
function real:GetBottom() return 100 end
function real:GetLeft() return 100 end
function real:GetRight() return 700 end
function real:GetTop() return 500 end
function real:GetEffectiveScale() return 1 end
function real:IsEnabled() return self.__enabled ~= false end
function real:Enable() self.__enabled = true end
function real:Disable() self.__enabled = false end
function real:SetEnabled(v) self.__enabled = v and true or false end
function real:GetFont() return "Fonts\\FRIZQT__.TTF", 12, "" end
function real:GetObjectType() return self.__type end
function real:GetFrameStrata() return self.__strata or "MEDIUM" end
function real:SetFrameStrata(s) self.__strata = s end

local function Maker(kind)
    return function(self, ...)
        local child = NewFrame(kind, nil, self)
        return child
    end
end
real.CreateTexture = Maker("Texture")
real.CreateFontString = Maker("FontString")
real.CreateMaskTexture = Maker("MaskTexture")
real.CreateAnimationGroup = Maker("AnimationGroup")

-- Anything not above: a no-op that returns the frame, so chains keep going
FrameMT.__index = function(table, key)
    local method = real[key]
    if method then return method end
    return function(...) return table end
end

-- A click, a key, any script: run it and let the error surface
function stub.Fire(frame, script, ...)
    local handler = frame.__scripts and frame.__scripts[script]
    if not handler then return false, "no handler" end
    local ok, err = pcall(handler, frame, ...)
    return ok, err
end

function stub.Install(G)
    _G = G
    G.CreateFrame = function(frameType, name, parent, template)
        return NewFrame(frameType, name, parent)
    end
    G.UIParent = NewFrame("Frame", "UIParent", nil)
    G.UIParent.__width, G.UIParent.__height = 1920, 1080
    G.WorldFrame = NewFrame("Frame", "WorldFrame", nil)
    G.Minimap = NewFrame("Frame", "Minimap", G.UIParent)
    G.MinimapCluster = NewFrame("Frame", "MinimapCluster", G.UIParent)
    G.GameTooltip = NewFrame("GameTooltip", "GameTooltip", nil)
    G.ColorPickerFrame = NewFrame("Frame", "ColorPickerFrame", nil)
    G.UISpecialFrames = {}
    G.StaticPopupDialogs = {}
    G.SOUNDKIT = setmetatable({}, { __index = function() return 1 end })
    G.FACTION_BAR_COLORS = setmetatable({}, {
        __index = function() return { r = 0, g = 0.6, b = 0.1 } end,
    })
    G.NORMAL_FONT_COLOR = { r = 1, g = 0.82, b = 0 }

    local function Zero() return 0 end
    local nilers = {
        "PlaySound", "StaticPopup_Show", "StaticPopup_Hide", "C_Timer",
        "GetXPExhaustion", "GetWatchedFactionInfo", "C_Reputation",
    }
    G.PlaySound = function() end
    G.StaticPopup_Show = function() end
    G.StaticPopup_Hide = function() end
    G.C_Timer = { After = function(_, fn) if fn then fn() end end, NewTicker = function() return {} end }
    G.GetXPExhaustion = function() return 1200 end
    G.GetWatchedFactionInfo = function() return "Argent Dawn", 5, 0, 12000, 4200 end
    G.C_Reputation = nil
    G.UnitXP = function() return 5000 end
    G.UnitXPMax = function() return 12000 end
    G.UnitLevel = function() return 42 end
    G.UnitName = function() return "Tester" end
    G.UnitClass = function() return "Mage", "MAGE" end
    G.UnitFactionGroup = function() return "Alliance" end
    G.IsXPUserDisabled = function() return false end
    G.GetMaxPlayerLevel = function() return 80 end
    G.GetRestState = function() return 1, "Rested", 1.5 end
    G.GetQuestLogRewardXP = Zero
    G.GetNumQuestLogEntries = Zero
    G.GetLocale = function() return "enUS" end
    G.GetRealmName = function() return "Forever" end
    G.GetTime = function() return 1000 end
    G.time = os.time
    G.date = os.date
    G.InCombatLockdown = function() return false end
    G.IsAddOnLoaded = function() return false end
    G.GetAddOnMetadata = function(_, field) return field == "Version" and "test" or "" end
    G.C_AddOns = {
        GetAddOnMetadata = function(_, field) return field == "Version" and "test" or "" end,
        IsAddOnLoaded = function() return false end,
    }
    -- LibSharedMedia, as another addon would have registered it, with
    -- enough fonts that the picker has to paginate
    local shared = { "Accidental Presidency", "Continuum Medium", "Expressway",
        "Myriad Condensed Web", "PT Sans Narrow", "Roboto", "Emblem", "Homespun",
        "Prototype", "Skurri Clone", "Friz Clone", "Movatif", "Oswald", "Lato",
        "Inter", "Noto Sans", "Fira Sans", "Cabin" }
    local lsm = {
        List = function(_, kind) return kind == "font" and shared or {} end,
        Fetch = function(_, kind, name) return "Fonts/" .. tostring(name) .. ".ttf" end,
    }
    G.LibStub = function(name, silent) return name == "LibSharedMedia-3.0" and lsm or nil end
    G.DEFAULT_CHAT_FRAME = { AddMessage = function() end }
    G.SlashCmdList = {}
    G.hooksecurefunc = function() end
    G.strsplit = function(sep, text)
        local out = {}
        for piece in tostring(text):gmatch("([^" .. sep .. "]*)") do table.insert(out, piece) end
        return unpack(out)
    end
    G.tinsert = table.insert
    G.tremove = table.remove
    G.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
    G.CreateColor = function(r, g, b, a) return { r = r, g = g, b = b, a = a } end
    G.CreateFont = function(name)
        local font = NewFrame("Font", name, nil)
        return font
    end
    G.Mixin = function(target) return target end
    G.BackdropTemplateMixin = {}
    G.unpack = unpack or table.unpack
    G.LE_EXPANSION_LEVEL_CURRENT = 10
    return G
end

return stub
