local ADDON_NAME, ns = ...

-- =========================================================
-- PERSIST: WoW Forever beta workaround
-- =========================================================
-- On the Forever beta, SavedVariables survive a /reload but are not read back
-- after a relog or a restart. The client does keep addon-registered CVars, so
-- every saved table is mirrored there too.
--
-- The CVars are not available yet when the addon loads: the copy is read back
-- at login (several tries), and nothing is saved before that, so the copy is
-- never overwritten with default settings. Each save is dated (_savedAt) and
-- the most recent version wins.
local Persist = {}
ns.Persist = Persist

local CHUNK = 200      -- Characters per CVar
local MAX_CHUNKS = 60  -- Up to 12 000 characters per saved table
local SAVE_EVERY = 20  -- Seconds
local LAST_RESTORE_DELAY = 3 -- Seconds after entering the world

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
local entries = {}
local ready = false -- No saving before the copies have been read back

function Persist.Register(name, getter, restore)
    tinsert(entries, { name = name, getter = getter, restore = restore })
end

local function ResolveName(entry)
    if type(entry.name) == "function" then return entry.name() end
    return entry.name
end

local function TryRestore()
    for _, entry in ipairs(entries) do
        local live = entry.getter()
        local saved = Persist.Load(ResolveName(entry))
        if type(live) == "table" and saved then
            -- Copies from older versions have no date: they win over a live table without date
            if (saved._savedAt or 1) > (live._savedAt or 0) then
                local ok = pcall(entry.restore, saved)
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
        end
    end
end
Persist.SaveAll = SaveAll

-- For /... debug commands: shows what is saved
function Persist.Debug(print)
    print("CVar API: " .. (HasAPI() and "yes" or "NO") .. "  ·  saving: " .. (ready and "on" or "waiting"))
    for _, entry in ipairs(entries) do
        local name = ResolveName(entry)
        local saved, chunks = Persist.Load(name)
        local live = entry.getter()
        print(string.format("%s: backup %s (%d part(s), %s)  ·  current %s  ·  restored: %s",
            name,
            saved and "OK" or "MISSING",
            chunks or 0,
            saved and saved._savedAt and date("%d/%m %H:%M:%S", saved._savedAt) or "-",
            type(live) == "table" and live._savedAt and date("%d/%m %H:%M:%S", live._savedAt) or "-",
            entry.restored and "yes" or "no"))
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("VARIABLES_LOADED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_LOGOUT")
events:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGOUT" then
        SaveAll()
    elseif event == "PLAYER_ENTERING_WORLD" then
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
        TryRestore()
        -- Last try once everything is loaded, then saving can start
        C_Timer.After(LAST_RESTORE_DELAY, function()
            TryRestore()
            ready = true
            SaveAll()
        end)
    else
        TryRestore()
    end
end)

C_Timer.NewTicker(SAVE_EVERY, SaveAll)
