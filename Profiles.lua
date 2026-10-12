local ADDON_NAME, ns = ...

-- =========================================================
-- PROFILES: named sets of settings, one per character in use
-- =========================================================
-- Since 3.7 MyXPBarDB holds:
--   profiles       [name] = one set of settings
--   assign         [character key] = the name of the profile it uses
--   defaultProfile the name a character gets until it picks another
--   xpPerLevel     XP needed per level, learned while playing: the same
--                  numbers for every character, so they are kept once
--   language       the addon language, one for the whole account
--   seenVersion    the version whose news was already announced
--   schema         the shape of all this, so older saves can be converted
--
-- ns.db always points at the profile in use. Everything that reads a setting
-- goes through it, so there is nothing to save: changing the bar writes in
-- its profile, and that profile is what the next character picking it gets.
local Profiles = {}
ns.Profiles = Profiles

local SCHEMA = 2       -- 1: 3.6, one shared set plus a hidden one per character
local NAME_MAX = 20    -- Characters, and a macro body only holds 255
local NEWS_DELAY = 2   -- Seconds after the saved copies came back

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

-- A name a player can type: trimmed, short enough, and without the ";" that
-- separates the fields of the macro copy
function Profiles.CleanName(name)
    if type(name) ~= "string" then return nil end
    name = name:gsub("[;\n\r]", " ")
    name = name:gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" then return nil end
    if #name > NAME_MAX then
        name = name:sub(1, NAME_MAX)
        name = name:gsub("%s+$", "")
    end
    return name ~= "" and name or nil
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

-- "Raid" if it is free, otherwise "Raid 2", "Raid 3"...
local function FreeName(wanted)
    if not container.profiles[wanted] then return wanted end
    for i = 2, 99 do
        local try = wanted .. " " .. i
        if not container.profiles[try] then return try end
    end
    return nil
end

-- Stores a copy of "from" under a free name and returns that name
local function AddProfile(wanted, from)
    local name = FreeName(Profiles.CleanName(wanted) or "Profile")
    if not name then return nil end
    container.profiles[name] = NewSettings(from)
    return name
end

-- Settings saved before 3.6 sat at the top level of MyXPBarDB; in 3.6 there
-- was one shared set plus a hidden one per character. Both become named
-- profiles, so nobody loses the bar they had set up.
local function Migrate()
    local c = container
    if type(c.xpPerLevel) ~= "table" then c.xpPerLevel = {} end

    if c.schema ~= SCHEMA then
        local old = (type(c.profiles) == "table") and c.profiles or {}
        local shared = c.shared
        if type(shared) ~= "table" then
            -- Before 3.6: every setting sat at the top level
            shared = {}
            for key in pairs(ns.defaults) do
                if c[key] ~= nil then shared[key] = c[key] end
            end
        end
        if type(shared.xpPerLevel) == "table" and not next(c.xpPerLevel) then
            c.xpPerLevel = shared.xpPerLevel
        end

        c.profiles, c.assign = {}, {}
        -- What everybody used becomes the first profile
        c.defaultProfile = AddProfile(ns.T("PROFILE_DEFAULT"), shared)
        -- A character that had its own set keeps it, under its own name
        for charKey, profile in pairs(old) do
            if type(profile) == "table" and profile.own then
                c.assign[charKey] = AddProfile(charKey, profile)
            end
        end

        for key in pairs(ns.defaults) do c[key] = nil end
        c.shared, c.horizontalMenu = nil, nil
        c.schema = SCHEMA
    end

    if type(c.profiles) ~= "table" then c.profiles = {} end
    if type(c.assign) ~= "table" then c.assign = {} end
    for _, profile in pairs(c.profiles) do
        if type(profile) == "table" then
            profile.xpPerLevel, profile.own, profile.horizontalMenu = nil, nil, nil
            ns.CopyDefaults(ns.defaults, profile)
        end
    end
end

-- ---------------------------------------------------------
-- THE LIST, AND WHO USES WHAT
-- ---------------------------------------------------------
function Profiles.List()
    local list = {}
    if container then
        for name in pairs(container.profiles) do list[#list + 1] = name end
    end
    table.sort(list)
    return list
end

function Profiles.Count()
    local n = 0
    if container then
        for _ in pairs(container.profiles) do n = n + 1 end
    end
    return n
end

-- The profile a character gets until it picks another one
function Profiles.DefaultName()
    if not container then return nil end
    local name = container.defaultProfile
    if name and container.profiles[name] then return name end
    -- Lost somehow: the first one by name takes over
    container.defaultProfile = Profiles.List()[1]
    return container.defaultProfile
end

-- The name of the profile this character uses
function Profiles.Current()
    if not container then return nil end
    local key = Profiles.Key()
    local name = key and container.assign[key]
    if name and container.profiles[name] then return name end
    return Profiles.DefaultName()
end

-- The settings themselves. There is always one: an empty list would leave
-- the addon with nothing to read.
function Profiles.Active()
    if not container then return nil end
    if not next(container.profiles) then
        container.defaultProfile = AddProfile(ns.T("PROFILE_DEFAULT"), nil)
    end
    return container.profiles[Profiles.Current()]
end

-- Points ns.db at the profile this character must use
function Profiles.Activate()
    local profile = Profiles.Active()
    if profile then ns.db = profile end
end

-- Gives an existing profile to this character
function Profiles.Use(name)
    if not container or not container.profiles[name] then return false end
    local key = Profiles.Key()
    if key then container.assign[key] = name end
    Profiles.Activate()
    return true
end

-- Creates a profile from what is on screen and gives it to this character.
-- Returns the name, or nil and the reason.
function Profiles.Create(wanted)
    if not container then return nil, "PROFILE_NAME_BAD" end
    local name = Profiles.CleanName(wanted)
    if not name then return nil, "PROFILE_NAME_BAD" end
    if container.profiles[name] then return nil, "PROFILE_EXISTS" end
    container.profiles[name] = NewSettings(ns.db)
    Profiles.Use(name)
    return name
end

-- Removes a profile. The characters that used it go back to the default one,
-- and the last profile left can never be deleted.
function Profiles.Delete(name)
    if not container or not container.profiles[name] then return false end
    if Profiles.Count() <= 1 then return false end

    container.profiles[name] = nil
    if container.defaultProfile == name then
        container.defaultProfile = Profiles.List()[1]
    end
    for key, assigned in pairs(container.assign) do
        if assigned == name then container.assign[key] = nil end
    end
    Profiles.Activate()
    return true
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
-- character in WoW texts). Around 130 characters, a macro body holds 255.
local SETTINGS_VERSION = "1"
local FLAG_FIELDS = {
    "locked", "hideBlizzard", "playSound", "showText",
    "showRestedText", "smooth", "showGains", "showMinimap",
    "fullWidth", "showRepHover", -- 2.7: missing in older copies, defaults apply
    "showRepBar", "showSession", -- 2.8
    "horizontalMenu", -- 3.2, dead since 3.6: the flags are read by position
    "showQuestXP", -- 2.9
    "enabled", "maxLevelRep", "newsOnLogin", -- 3.6
    "own", -- 3.6, dead since 3.7: profiles have names now
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

-- A profile name holds anything the player typed, including the ";" that
-- separates the fields: everything outside a safe set is written as ~XX
local function EncodeName(name)
    return (tostring(name or ""):gsub("[^%w _%-]", function(c)
        return string.format("~%02X", c:byte())
    end))
end

local function DecodeName(text)
    if type(text) ~= "string" or text == "" then return nil end
    return (text:gsub("~(%x%x)", function(hex) return string.char(tonumber(hex, 16)) end))
end

local function EncodeSettings(s, savedAt, language, seen, profileName)
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
        EncodeName(profileName), -- 3.7, appended
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
        profileName = Profiles.CleanName(DecodeName(f[19])),  -- 3.7
    }
    for i, key in ipairs(FLAG_FIELDS) do
        local bit = f[13]:sub(i, i)
        if bit ~= "" then settings[key] = (bit == "1") end
    end
    return settings
end

-- The account macro: the default profile with its name, the language and the
-- flag of the news already read
local accountMacro = {
    name = "MyXPBar",
    encode = function(c)
        local name = Profiles.DefaultName()
        return EncodeSettings(c.profiles[name], c._savedAt, c.language, c.seenVersion, name)
    end,
    decode = function(data)
        local settings = DecodeSettings(data)
        if not settings then return nil end
        local saved = {
            _savedAt = settings._savedAt,
            language = settings.language,
            seenVersion = settings.seenVersion,
            schema = SCHEMA,
            profiles = {},
            assign = {},
            xpPerLevel = {},
        }
        local name = settings.profileName or ns.T("PROFILE_DEFAULT")
        settings._savedAt, settings.language = nil, nil
        settings.seenVersion, settings.profileName, settings.own = nil, nil, nil
        saved.profiles[name] = settings
        saved.defaultProfile = name
        return saved
    end,
}

-- One character macro per character, so the profile a character picked is
-- still there after a restart of the game. A character on the default
-- profile needs none: the account macro already carries that one.
local charMacro = {
    name = "MyXPBarChar",
    perChar = true,
    skip = function() return Profiles.Current() == Profiles.DefaultName() end,
    encode = function(profile)
        return EncodeSettings(profile, profile._savedAt, nil, nil, Profiles.Current())
    end,
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

    -- The language first: the name given to the first profile is translated
    if not container.language then container.language = ns.DefaultLanguage() end
    Migrate()
    Profiles.Activate()

    -- Forever beta: after a relog the settings come back from the CVar copy,
    -- after a restart from the macro copy (see Persist.lua)
    ns.Persist.Register("MyXPBarDB", function() return container end, function(saved)
        ns.Persist.Replace(container, saved)
        if not container.language then container.language = ns.DefaultLanguage() end
        Migrate()
        Profiles.hadData = true
        Profiles.Activate()
        if onRestored then onRestored() end
    end, accountMacro)

    -- The getter returns nil while the character is unknown: Persist simply
    -- skips the entry and tries again on the next event
    ns.Persist.Register(function() return "MyXPBarChar" .. (Profiles.Key() or "Unknown") end,
        function() return Profiles.Key() and Profiles.Active() or nil end,
        function(saved)
            local key = Profiles.Key()
            if not key then return end
            -- The copy carries the name of the profile this character used
            local name = Profiles.CleanName(saved.profileName) or Profiles.Current()
            saved.profileName = nil
            if type(container.profiles[name]) ~= "table" then
                container.profiles[name] = {}
            end
            ns.Persist.Replace(container.profiles[name], saved, ns.defaults)
            container.profiles[name].xpPerLevel = nil
            container.assign[key] = name
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
    if ns.RefreshOptions then ns.RefreshOptions() end
end)
