local ADDON_NAME, ns = ...

-- =========================================================
-- PERSIST: WoW Forever beta workaround
-- =========================================================
-- On the Forever beta, SavedVariables survive a /reload but are not read back
-- after a relog or a restart. Two copies cover for it:
--
-- * Addon-registered CVars. They stay in memory while the game runs, so they
--   cover a relog, but the client never writes them to disk: they are gone
--   after a restart.
-- * One account macro holding a compact copy of the settings. Macros are kept
--   by the server and are always there after a restart. Only tables that give
--   an encoder get one (a macro body holds 255 characters).
--
-- None of the copies are available yet when the addon loads: they are read
-- back at login (several tries), and nothing is saved before that, so a copy
-- is never overwritten with default settings. Each save is dated (_savedAt)
-- and the most recent version wins.
local Persist = {}
ns.Persist = Persist

local CHUNK = 200      -- Characters per CVar
local MAX_CHUNKS = 60  -- Up to 12 000 characters per saved table
local SAVE_EVERY = 5   -- Seconds
local LAST_RESTORE_DELAY = 3 -- Seconds after entering the world
local MACRO_WAIT = 15  -- Longest wait for the macros after entering the world
local MACRO_BODY_MAX = 255
local MACRO_ICON = 134400 -- Question mark
local MACRO_DATA_PREFIX = "#d;"

local function HasAPI()
    return C_CVar and C_CVar.RegisterCVar and C_CVar.GetCVar and C_CVar.SetCVar
end

local registered = {}
local function Register(name)
    if not registered[name] then
        pcall(C_CVar.RegisterCVar, name, "")
        registered[name] = true
    end
end

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

-- ---------------------------------------------------------
-- Serialization (no quotes or newlines, safe for the config file)
-- ---------------------------------------------------------
local function EncodeString(s)
    return (s:gsub("[^%w _%.,:/%-]", function(c) return string.format("%%%02X", c:byte()) end))
end

local function DecodeString(s)
    return (s:gsub("%%(%x%x)", function(hex) return string.char(tonumber(hex, 16)) end))
end

local function Serialize(value, depth)
    local kind = type(value)
    if kind == "number" then
        return "n" .. tostring(value)
    elseif kind == "boolean" then
        return value and "t" or "f"
    elseif kind == "string" then
        return "s" .. EncodeString(value)
    elseif kind == "table" and depth < 10 then
        local parts = {}
        for k, v in pairs(value) do
            local ks, vs = Serialize(k, depth + 1), Serialize(v, depth + 1)
            if ks and vs then parts[#parts + 1] = ks .. "=" .. vs end
        end
        return "{" .. table.concat(parts, ";") .. "}"
    end
    return nil -- Functions, frames...: not saved
end

local function Parse(s, pos)
    local c = s:sub(pos, pos)
    if c == "{" then
        local tbl = {}
        pos = pos + 1
        if s:sub(pos, pos) == "}" then return tbl, pos + 1 end
        while true do
            local k, v
            k, pos = Parse(s, pos)
            if s:sub(pos, pos) ~= "=" then error("bad data") end
            v, pos = Parse(s, pos + 1)
            if k ~= nil then tbl[k] = v end
            local sep = s:sub(pos, pos)
            if sep == ";" then
                pos = pos + 1
            elseif sep == "}" then
                return tbl, pos + 1
            else
                error("bad data")
            end
        end
    elseif c == "t" then
        return true, pos + 1
    elseif c == "f" then
        return false, pos + 1
    elseif c == "n" or c == "s" then
        local stop = s:find("[=;}]", pos + 1) or (#s + 1)
        local raw = s:sub(pos + 1, stop - 1)
        if c == "n" then return tonumber(raw), stop end
        return DecodeString(raw), stop
    end
    error("bad data")
end

-- ---------------------------------------------------------
-- Raw save / load
-- ---------------------------------------------------------
-- Letters and digits only, for per-character CVar names
function Persist.CharKey()
    local key = ((UnitName("player") or "") .. (GetRealmName() or "")):gsub("[^%w]", "")
    return key ~= "" and key or "Char"
end

local lastSaved = {}

function Persist.Save(name, tbl)
    if not HasAPI() or type(tbl) ~= "table" then return end

    -- Compare without the date, otherwise every save would look different
    local stamp = tbl._savedAt
    tbl._savedAt = nil
    local ok, content = pcall(Serialize, tbl, 0)
    if not ok or not content then
        tbl._savedAt = stamp
        return
    end
    if lastSaved[name] == content then
        tbl._savedAt = stamp -- Nothing changed: don't touch the CVars
        return
    end
    lastSaved[name] = content

    tbl._savedAt = time()
    local okStamped, data = pcall(Serialize, tbl, 0)
    if not okStamped or not data then return end

    local count = math.ceil(#data / CHUNK)
    if count > MAX_CHUNKS then return end -- Too big: keep the previous save
    for i = 1, count do
        local cvar = name .. i
        Register(cvar)
        pcall(C_CVar.SetCVar, cvar, data:sub((i - 1) * CHUNK + 1, i * CHUNK))
    end
    -- An empty chunk marks the end
    Register(name .. (count + 1))
    pcall(C_CVar.SetCVar, name .. (count + 1), "")
end

function Persist.Load(name)
    if not HasAPI() then return nil end
    local parts = {}
    for i = 1, MAX_CHUNKS do
        local cvar = name .. i
        Register(cvar)
        local ok, value = pcall(C_CVar.GetCVar, cvar)
        if not ok or not value or value == "" then break end
        parts[#parts + 1] = value
    end
    if #parts == 0 then return nil, 0 end
    local ok, tbl = pcall(Parse, table.concat(parts), 1)
    if ok and type(tbl) == "table" then return tbl, #parts end
    return nil, #parts
end

-- Replaces the content of target with saved (keeps the same table, so every
-- reference to it stays valid), then fills missing settings with defaults
function Persist.Replace(target, saved, defaults)
    for k in pairs(target) do target[k] = nil end
    for k, v in pairs(saved) do target[k] = v end
    if defaults then CopyDefaults(defaults, target) end
end

-- ---------------------------------------------------------
-- Managed tables
-- ---------------------------------------------------------
-- name: CVar name, or a function returning it (for per-character names)
-- getter: returns the live table
-- restore(saved): called when the saved copy is more recent than the live table
-- macro (optional): { name = macro name, encode = fn(table) -> string,
--                     decode = fn(string) -> table or nil }
local entries = {}
local ready = false       -- No saving before the copies have been read back
local macrosLoaded = false -- The server sends the macros a moment after login

function Persist.Register(name, getter, restore, macro)
    tinsert(entries, { name = name, getter = getter, restore = restore, macro = macro })
end

local function ResolveName(entry)
    if type(entry.name) == "function" then return entry.name() end
    return entry.name
end

-- ---------------------------------------------------------
-- Macro copy
-- ---------------------------------------------------------
local function MacroAPI()
    return GetMacroIndexByName and GetMacroInfo and CreateMacro and EditMacro and GetNumMacros
end

local function MacrosAvailable()
    if not MacroAPI() then return false end
    return macrosLoaded or (GetNumMacros() or 0) > 0
end

-- Index of our macro among the account macros, or nil
local function FindMacro(macroName)
    local index = GetMacroIndexByName(macroName)
    if index and index > 0 and index <= (MAX_ACCOUNT_MACROS or 120) then return index end
    return nil
end

local function MacroBody(macroName, data)
    return "#" .. macroName .. " settings, keep this macro\n" .. MACRO_DATA_PREFIX .. data
end

local function ReadMacro(spec)
    if not MacrosAvailable() then return nil end
    local index = FindMacro(spec.name)
    if not index then return nil end
    local _, _, body = GetMacroInfo(index)
    local data = body and body:match(MACRO_DATA_PREFIX:gsub("%p", "%%%0") .. "([^\n]*)")
    if not data then return nil end
    local ok, tbl = pcall(spec.decode, data)
    if ok and type(tbl) == "table" then return tbl end
    return nil
end

local warnedFull = false

-- Returns true once the macro holds exactly this data
local function WriteMacro(spec, data)
    if not MacrosAvailable() or InCombatLockdown() then return false end
    local body = MacroBody(spec.name, data)
    if #body > MACRO_BODY_MAX then return false end

    local index = FindMacro(spec.name)
    if index then
        local _, _, current = GetMacroInfo(index)
        if current == body then return true end
        return (pcall(EditMacro, index, spec.name, nil, body))
    end

    if (GetNumMacros() or 0) >= (MAX_ACCOUNT_MACROS or 120) then
        if not warnedFull then
            warnedFull = true
            DEFAULT_CHAT_FRAME:AddMessage("|cff9966ff" .. ADDON_NAME .. "|r: all account macro slots are used, "
                .. "your settings will not survive a restart. Free one slot and /reload.")
        end
        return false
    end
    return (pcall(CreateMacro, spec.name, MACRO_ICON, body, false))
end

-- ---------------------------------------------------------
-- Restore and save
-- ---------------------------------------------------------
local function TryRestore()
    for _, entry in ipairs(entries) do
        local live = entry.getter()
        if type(live) == "table" then
            -- The newest copy wins, CVar or macro
            local best = Persist.Load(ResolveName(entry))
            local fromMacro = entry.macro and ReadMacro(entry.macro)
            if fromMacro and (fromMacro._savedAt or 0) > ((best and best._savedAt) or 0) then
                best = fromMacro
            end
            -- Copies from older versions have no date: they win over a live table without date
            if best and (best._savedAt or 1) > (live._savedAt or 0) then
                local ok = pcall(entry.restore, best)
                entry.restored = ok or entry.restored
            end
        end
    end
end

local function SaveAll()
    if not ready then return end
    for _, entry in ipairs(entries) do
        local ok, tbl = pcall(entry.getter)
        if ok and type(tbl) == "table" then
            Persist.Save(ResolveName(entry), tbl) -- Dates and skips unchanged data itself
            if entry.macro then
                if not tbl._savedAt then tbl._savedAt = time() end
                -- WriteMacro skips an unchanged macro, recreates a deleted one, and
                -- is refused in combat: the next tick simply tries again
                local encoded, data = pcall(entry.macro.encode, tbl)
                if encoded and data then WriteMacro(entry.macro, data) end
            end
        end
    end
end
Persist.SaveAll = SaveAll

-- For /... debug commands: shows what is saved
function Persist.Debug(print)
    print("CVar API: " .. (HasAPI() and "yes" or "NO")
        .. "  ·  macros: " .. (MacrosAvailable() and "loaded" or "waiting")
        .. "  ·  saving: " .. (ready and "on" or "waiting"))
    for _, entry in ipairs(entries) do
        local name = ResolveName(entry)
        local saved, chunks = Persist.Load(name)
        local live = entry.getter()
        print(string.format("%s: CVar copy %s (%d part(s), %s)  ·  current %s  ·  restored: %s",
            name,
            saved and "OK" or "MISSING",
            chunks or 0,
            saved and saved._savedAt and date("%d/%m %H:%M:%S", saved._savedAt) or "-",
            type(live) == "table" and live._savedAt and date("%d/%m %H:%M:%S", live._savedAt) or "-",
            entry.restored and "yes" or "no"))
        if entry.macro then
            local fromMacro = ReadMacro(entry.macro)
            print(string.format("%s: macro copy %s (%s)",
                entry.macro.name,
                fromMacro and "OK" or "MISSING",
                fromMacro and fromMacro._savedAt and date("%d/%m %H:%M:%S", fromMacro._savedAt) or "-"))
        end
    end
end

-- Saving starts once every copy had its chance to be read back. Saving
-- without the macros could create a second macro with default settings, so
-- after the usual delay it still waits for them (at most MACRO_WAIT seconds).
local delayPassed = false
local finished = false
local function FinishRestore()
    if finished then return end
    finished = true
    TryRestore()
    ready = true
    SaveAll()
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("VARIABLES_LOADED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_LOGOUT")
events:RegisterEvent("UPDATE_MACROS")
events:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGOUT" then
        SaveAll()
    elseif event == "UPDATE_MACROS" then
        macrosLoaded = true
        if delayPassed then FinishRestore() elseif not ready then TryRestore() end
    elseif event == "PLAYER_ENTERING_WORLD" then
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
        TryRestore()
        C_Timer.After(LAST_RESTORE_DELAY, function()
            delayPassed = true
            if MacrosAvailable() then FinishRestore() end
        end)
        -- No macro at all on the account: nothing will arrive, saving can start
        C_Timer.After(MACRO_WAIT, function()
            macrosLoaded = true
            FinishRestore()
        end)
    else
        TryRestore()
    end
end)

C_Timer.NewTicker(SAVE_EVERY, SaveAll)
