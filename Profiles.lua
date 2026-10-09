local ADDON_NAME, ns = ...

-- =========================================================
-- PROFILES: the settings of the account, or of one character
-- =========================================================
-- Since 3.6 MyXPBarDB holds:
--   shared      the settings a character uses unless it has its own
--   profiles    [key] = the settings of one character. The "own" field decides
--               whether that character actually uses them.
--   xpPerLevel  XP needed per level, learned while playing: the same numbers
--               for every character, so they are kept once for the account
--   language    the addon language, one for the whole account
--   seenVersion the version whose news was already announced
--
-- ns.db always points at the settings in use. Everything that reads a setting
-- goes through it, so switching profile is a new ns.db plus a Refresh.
local Profiles = {}
ns.Profiles = Profiles

local NEWS_DELAY = 2 -- Seconds after the saved copies came back

local container  -- MyXPBarDB
local onRestored -- Called when a saved copy came back, to redraw everything

Profiles.hadData = false -- false only for a brand new install: no news then

-- ---------------------------------------------------------
-- KEYS AND NAMES
-- ---------------------------------------------------------
-- On the Forever beta UnitName can raise an error on a protected value:
-- never call it without a wrapper.
local function PlayerName()
    local ok, name = pcall(UnitName, "player")
    if ok and type(name) == "string" and name ~= "" then return name end
    return nil
end

local function RealmName()
    local ok, realm = pcall(GetRealmName)
    if ok and type(realm) == "string" and realm ~= "" then return realm end
    return nil
end

-- Letters and digits only: this ends up in a CVar name. nil while the game
-- cannot tell who we are yet, which happens at ADDON_LOADED on some clients:
-- a shared key would then be handed to the wrong character.
function Profiles.Key()
    local name = PlayerName()
    if not name then return nil end
    local key = (name .. (RealmName() or "")):gsub("[^%w]", "")
    return key ~= "" and key or nil
end

-- What the options menu shows
function Profiles.CharName()
    local name = PlayerName()
    if not name then return "?" end
    local realm = RealmName()
    return realm and (name .. " - " .. realm) or name
end

-- ---------------------------------------------------------
-- SETTINGS TABLES
-- ---------------------------------------------------------
-- A copy of a settings table, without what belongs to the storage itself
local function NewSettings(from)
    local settings = {}
    if type(from) == "table" then
        for k, v in pairs(from) do
            if k ~= "_savedAt" and k ~= "own" and k ~= "xpPerLevel" then
                if type(v) == "table" then
                    settings[k] = ns.CopyDefaults(v, {}) -- Deep copy
                else
                    settings[k] = v
                end
            end
        end
    end
    return ns.CopyDefaults(ns.defaults, settings)
end

local function Overwrite(target, source)
    wipe(target)
    for k, v in pairs(source) do target[k] = v end
end

-- Settings saved before 3.6 sat at the top level of MyXPBarDB. They become the
-- shared profile, so nobody loses the bar they had set up.
local function Migrate()
    local c = container
    if type(c.shared) ~= "table" then
        local shared = {}
        for key in pairs(ns.defaults) do
            if c[key] ~= nil then shared[key] = c[key] end
        end
        c.shared = shared
    end
    if type(c.profiles) ~= "table" then c.profiles = {} end

    -- The learned XP per level is the same for every character
    if type(c.xpPerLevel) ~= "table" then
        c.xpPerLevel = (type(c.shared.xpPerLevel) == "table" and c.shared.xpPerLevel) or {}
    end

    c.shared.xpPerLevel = nil
    c.shared.own = nil -- Only a character profile carries it
    ns.CopyDefaults(ns.defaults, c.shared)

    -- Nothing reads the old flat keys any more
    for key in pairs(ns.defaults) do c[key] = nil end

    for _, profile in pairs(c.profiles) do
        if type(profile) == "table" then
            profile.xpPerLevel = nil
            ns.CopyDefaults(ns.defaults, profile)
        end
    end
end

-- This character's profile, created from the shared settings if it is new.
-- nil until the character is known.
function Profiles.CharTable()
    if not container then return nil end
    local key = Profiles.Key()
    if not key then return nil end
    local profile = container.profiles[key]
    if type(profile) ~= "table" then
        profile = NewSettings(container.shared)
        profile.own = false
        container.profiles[key] = profile
    end
    return profile
end

function Profiles.UsesOwn()
    local profile = Profiles.CharTable()
    return (profile and profile.own) and true or false
end

-- Points ns.db at the settings this character must use
function Profiles.Activate()
    if not container then return end
    local profile = Profiles.CharTable()
    ns.db = (profile and profile.own and profile) or container.shared
end

-- Turns the character profile on (starting from what is on screen) or off
function Profiles.SetOwn(on)
    local profile = Profiles.CharTable()
    if not profile then return end
    if on then
        local copy = NewSettings(ns.db)
        Overwrite(profile, copy)
        profile.own = true
    else
        profile.own = false
    end
    Profiles.Activate()
end

-- The shared settings land on this character, which keeps its own from now on
function Profiles.CopyFromShared()
    local profile = Profiles.CharTable()
    if not profile then return end
    Overwrite(profile, NewSettings(container.shared))
    profile.own = true
    Profiles.Activate()
end

-- What this character uses becomes what every other character starts from
function Profiles.SaveAsShared()
    if not container then return end
    local copy = NewSettings(ns.db)
    Overwrite(container.shared, copy)
    container.shared.own = nil
    Profiles.Activate()
end

-- Learned XP per level: account wide, the numbers are the same for everyone
function ns.XPPerLevel()
    if container and type(container.xpPerLevel) == "table" then
        return container.xpPerLevel
    end
    return {}
end

-- ---------------------------------------------------------
-- VERSION AND NEWS
-- ---------------------------------------------------------
function ns.AddonVersion()
    local meta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    if not meta then return "?" end
    local ok, version = pcall(meta, ADDON_NAME, "Version")
    if ok and type(version) == "string" and version ~= "" then return version end
    return "?"
end

-- Announces the news once per version, never on a brand new install, and only
-- after the saved copies came back (otherwise a restored "already seen" flag
-- would arrive too late and the player would read the same news twice).
function Profiles.CheckNews()
    if not container then return end
    local version = ns.AddonVersion()
    if version == "?" or container.seenVersion == version then return end

    local firstInstall = (not Profiles.hadData) and container.seenVersion == nil
    container.seenVersion = version
    if firstInstall or not ns.db.newsOnLogin then return end
    if ns.AnnounceNews then ns.AnnounceNews(version) end
end

-- =========================================================
-- COMPACT COPY (the macro, see Persist.lua)
-- =========================================================
-- One line, fields in a fixed order, separated by ";" ("|" is an escape
-- character in WoW texts). Around 110 characters, a macro body holds 255.
local SETTINGS_VERSION = "1"
local FLAG_FIELDS = {
    "locked", "hideBlizzard", "playSound", "showText",
    "showRestedText", "smooth", "showGains", "showMinimap",
    "fullWidth", "showRepHover", -- 2.7: missing in older copies, defaults apply
    "showRepBar", "showSession", -- 2.8
    "horizontalMenu", -- 3.2
    "showQuestXP", -- 2.9
    "enabled", "maxLevelRep", "newsOnLogin", "own", -- 3.6
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

local function EncodeSettings(s, savedAt, language, seen)
    local flags = {}
    for i, key in ipairs(FLAG_FIELDS) do flags[i] = s[key] and "1" or "0" end
    local p = s.point
    return table.concat({
        SETTINGS_VERSION,
        string.format("%d", savedAt or time()),
        p[1], p[2], string.format("%.1f", p[3]), string.format("%.1f", p[4]),
        string.format("%d", math.floor(s.width + 0.5)),
        string.format("%d", math.floor(s.height + 0.5)),
        ColorToHex(s.xpColor), ColorToHex(s.restedColor),
        string.format("%d", math.floor(s.bgAlpha * 100 + 0.5)),
        s.style,
        table.concat(flags),
        string.format("%d", math.floor(s.minimap.angle + 0.5)),
        language or "",
        string.format("%d", math.floor(s.targetLevel or 0)), -- 2.8, appended
        s.texture or "default",                              -- 3.5, appended
        -- 3.6, appended. The parentheses drop the count gsub also returns,
        -- which would otherwise become a field of its own.
        ((seen or ""):gsub("[^%w%.]", "")),
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
        targetLevel = tonumber(f[16]), -- nil in copies written before 2.8
        -- nil in copies written before 3.5: the default texture stays
        texture = f[17] and f[17]:match("^%a+$") or nil,
        seenVersion = f[18] and f[18] ~= "" and f[18] or nil, -- 3.6
    }
    for i, key in ipairs(FLAG_FIELDS) do
        local bit = f[13]:sub(i, i)
        if bit ~= "" then settings[key] = (bit == "1") end
    end
    return settings
end

-- The account macro: the shared settings, the language and the news flag
local accountMacro = {
    name = "MyXPBar",
    encode = function(c)
        return EncodeSettings(c.shared, c._savedAt, c.language, c.seenVersion)
    end,
    decode = function(data)
        local s = DecodeSettings(data)
        if not s then return nil end
        local saved = {
            shared = s,
            _savedAt = s._savedAt,
            language = s.language,
            seenVersion = s.seenVersion,
        }
        s._savedAt, s.language, s.seenVersion, s.own = nil, nil, nil, nil
        return saved
    end,
}

-- One character macro per character, so a profile is still there after a
-- restart of the game. Characters on the shared settings get none.
local charMacro = {
    name = "MyXPBarChar",
    perChar = true,
    skip = function(profile) return not profile.own end,
    encode = function(profile) return EncodeSettings(profile, profile._savedAt) end,
    decode = DecodeSettings,
}

-- =========================================================
-- START UP
-- =========================================================
-- Called from ADDON_LOADED with the saved variables. restored() is called
-- every time a copy came back, so the bar and the menu can be redrawn.
function Profiles.Init(savedVariables, restored)
    container = savedVariables
    ns.container = container
    onRestored = restored
    Profiles.hadData = next(container) ~= nil

    Migrate()
    if not container.language then container.language = ns.DefaultLanguage() end
    Profiles.Activate()

    -- Forever beta: after a relog the settings come back from the CVar copy,
    -- after a restart from the macro copy (see Persist.lua)
    ns.Persist.Register("MyXPBarDB", function() return container end, function(saved)
        ns.Persist.Replace(container, saved)
        Migrate()
        if not container.language then container.language = ns.DefaultLanguage() end
        Profiles.hadData = true
        Profiles.Activate()
        if onRestored then onRestored() end
    end, accountMacro)

    -- The getter returns nil while the character is unknown: Persist simply
    -- skips the entry and tries again on the next event
    ns.Persist.Register(function() return "MyXPBarChar" .. (Profiles.Key() or "Unknown") end,
        function() return Profiles.CharTable() end,
        function(saved)
            local profile = Profiles.CharTable()
            if not profile then return end
            ns.Persist.Replace(profile, saved, ns.defaults)
            profile.xpPerLevel = nil
            Profiles.hadData = true
            Profiles.Activate()
            if onRestored then onRestored() end
        end, charMacro)

    ns.Persist.OnReady(function()
        C_Timer.After(NEWS_DELAY, Profiles.CheckNews)
    end)
end

-- The character is not always known at ADDON_LOADED: the profile is picked
-- again as soon as the game can tell, and the bar redrawn if it changed.
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent", function()
    if not container then return end
    local before = ns.db
    Profiles.Activate()
    if ns.db == before then return end
    ns.Refresh()
    if ns.UpdateMinimapButton then ns.UpdateMinimapButton() end
    if ns.LayoutOptions then ns.LayoutOptions() end
    if ns.RefreshOptions then ns.RefreshOptions() end
end)
