-- Loads the addon in the fake client of wowstub.lua and clicks everything.
-- Catches at the desk what only the game used to tell us: a handler that
-- errors, a widget built from a nil, a drop-down that opens on nothing.
--
--   python tools/run_simulate.py

local here = (...) or "."
package.path = here .. "/?.lua;" .. package.path
local stub = require("wowstub")
stub.Install(_G)

local ADDON = "MyXPBar"
local ns = {}
local failures = {}

local function Load(file)
    local chunk, err = loadfile(file)
    if not chunk then
        table.insert(failures, "cannot read " .. file .. ": " .. tostring(err))
        return
    end
    local ok, runErr = pcall(chunk, ADDON, ns)
    if not ok then
        table.insert(failures, "loading " .. file .. ": " .. tostring(runErr))
    end
end

for _, file in ipairs({ "Locales.lua", "Persist.lua", "Profiles.lua", "MyXPBar.lua", "Options.lua" }) do
    Load(file)
end

-- The addon waits for ADDON_LOADED before it has settings to draw from
local loaded = 0
for _, frame in ipairs(stub.frames) do
    local onEvent = frame.__scripts and frame.__scripts.OnEvent
    if onEvent then
        local ok, err = pcall(onEvent, frame, "ADDON_LOADED", ADDON)
        if not ok then table.insert(failures, "ADDON_LOADED: " .. tostring(err)) end
        local ok2, err2 = pcall(onEvent, frame, "PLAYER_ENTERING_WORLD")
        if not ok2 then table.insert(failures, "PLAYER_ENTERING_WORLD: " .. tostring(err2)) end
        loaded = loaded + 1
    end
end

local function Try(what, fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then table.insert(failures, what .. ": " .. tostring(err)) end
    return ok
end

Try("ns.Refresh", ns.Refresh)
Try("ns.LayoutOptions", ns.LayoutOptions)

-- Open the options menu, then click every button and tick every box
local panel = _G.MyXPBarOptionsFrame
if not panel then
    table.insert(failures, "the options menu was never built")
else
    panel.__shown = true
    ns.previewing = true
    Try("options OnShow", function() stub.Fire(panel, "OnShow") end)
    Try("ns.RefreshOptions", ns.RefreshOptions)
end

local clicked, ticked = 0, 0
for _, frame in ipairs(stub.frames) do
    local onClick = frame.__scripts and frame.__scripts.OnClick
    if onClick then
        if frame.__type == "CheckButton" then
            frame.__checked = not frame.__checked
            ticked = ticked + 1
        end
        local ok, err = pcall(onClick, frame, "LeftButton")
        if not ok then
            table.insert(failures, "a click on a " .. frame.__type ..
                (frame.__text ~= "" and (" (" .. tostring(frame.__text) .. ")") or "") ..
                ": " .. tostring(err))
        end
        clicked = clicked + 1
    end
end

-- The font list must answer a click with rows to pick from
local fontList = _G.MyXPBarFontList
if not fontList then
    table.insert(failures, "the font list does not exist")
else
    local rows = 0
    for _, child in ipairs(fontList.__children or {}) do
        if child.__type == "Button" then rows = rows + 1 end
    end
    if rows == 0 then
        table.insert(failures, "the font list opens on nothing: no row was built")
    end
    print(string.format("font list: %d rows, shown=%s", rows, tostring(fontList.__shown)))
end

-- What the menu ends up measuring, so a page that runs past the window
-- shows here instead of in a screenshot
if panel then
    local pageHeights = {}
    for _, child in ipairs(panel.__children or {}) do
        if child.__type == "Frame" and child.__width == 362 then
            table.insert(pageHeights, math.floor(child.__height + 0.5))
        end
    end
    table.sort(pageHeights, function(a, b) return a > b end)
    print(string.format("panel: %dx%d   pages (tall to short): %s",
        math.floor(panel.__width + 0.5), math.floor(panel.__height + 0.5),
        table.concat(pageHeights, ", ")))
    local tallest = pageHeights[1] or 0
    if tallest + 52 + 120 > panel.__height then
        table.insert(failures, string.format(
            "the tallest page (%d) does not fit the window (%d): the footer is under it",
            tallest, math.floor(panel.__height + 0.5)))
    end
end

print(string.format("frames built: %d   event frames: %d   clicks: %d (%d boxes)",
    #stub.frames, loaded, clicked, ticked))

if #failures == 0 then
    print("no error")
else
    print(string.format("%d problem(s):", #failures))
    for _, line in ipairs(failures) do print("  - " .. line) end
end
os.exit(#failures == 0 and 0 or 1)
