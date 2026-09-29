-- Mod key handling through SE's KeyInput event (client). A handled key is prevented, which makes
-- SE's SDL_PollEvent hook swallow it before the game sees it (verify per key and per UI state).
-- Keys injected with Ext.Input.InjectKeyPress do not pass through KeyInput.
--
-- Two layers, in order:
--  1. global actions (Keys.Action): named, bound to combos from the config ("CTRL+R");
--  2. the screen router (Keys.Router): the handler in front gets every other press as a combo
--     string ("DOWN", "SHIFT+TAB") and returns true when it used it.
local Log = Ext.Require("Core/Log.lua")
local Bridge = Ext.Require("Core/Bridge.lua")
local Config = Ext.Require("Core/Config.lua")

local Keys = {}

Keys.Router = nil -- function(combo) -> handled
-- function(combo): told of every press the mod let through to the game (no return value). The
-- combat tracker uses it to know that a change of the controlled character came from the player's
-- own key (F1-F4, [ ]) and to say it at once.
Keys.Observer = nil

local actions = {}  -- id -> fn
local order = {}    -- ids in registration order (help lists them in this order)
local bindings = {} -- combo -> id
local claimed = {}  -- scancode name -> true while a claimed press is held (its release is swallowed too)

-- Normalized combo: modifiers in the order CTRL, SHIFT, ALT, then the SDL scancode name.
function Keys.Combo(key, mods)
    local parts = {}
    local m = tostring(mods or "")
    if m:find("Ctrl") then parts[#parts + 1] = "CTRL" end
    if m:find("Shift") then parts[#parts + 1] = "SHIFT" end
    if m:find("Alt") then parts[#parts + 1] = "ALT" end
    parts[#parts + 1] = tostring(key)
    return table.concat(parts, "+")
end

local function normalize(combo)
    local key, mods = nil, {}
    for p in combo:upper():gmatch("[^+]+") do
        if p == "CTRL" or p == "SHIFT" or p == "ALT" then mods[#mods + 1] = p:sub(1, 1) .. p:sub(2):lower() else key = p end
    end
    return key and Keys.Combo(key, table.concat(mods, ",")) or nil
end

-- Registers a global action. Its combos come from the config (keys.<id>).
function Keys.Action(id, fn)
    if not actions[id] then order[#order + 1] = id end
    actions[id] = fn
    for _, combo in ipairs(Config.KeysFor(id)) do
        local c = normalize(combo)
        if not c then
            Log.Error("config keys." .. id .. ": bad key '" .. tostring(combo) .. "'")
        elseif bindings[c] and bindings[c] ~= id then
            Log.Error("config keys." .. id .. ": " .. c .. " is already bound to " .. bindings[c])
        else
            bindings[c] = id
        end
    end
end

-- Combos bound to action id (sorted), e.g. { "CTRL+M" }.
function Keys.CombosFor(id)
    local combos = {}
    for c, bound in pairs(bindings) do
        if bound == id then combos[#combos + 1] = c end
    end
    table.sort(combos)
    return combos
end

-- { { id = , combos = {..} } } in registration order, for help.
function Keys.List()
    local out = {}
    for _, id in ipairs(order) do
        local combos = Keys.CombosFor(id)
        if #combos > 0 then out[#out + 1] = { id = id, combos = combos } end
    end
    return out
end

local function onKey(e)
    local key = tostring(e.Key)
    local combo = Keys.Combo(e.Key, e.Modifiers)
    if Config.Get("debug.logKeys") then
        Bridge.Log(string.format("key %s %s%s", combo, e.Pressed and "down" or "up", e.Repeat and " repeat" or ""))
    end
    if not e.Pressed then
        if claimed[key] then
            claimed[key] = nil
            e:PreventAction()
        end
        return
    end
    local id = bindings[combo]
    if id then
        e:PreventAction()
        claimed[key] = true
        if not e.Repeat then Log.Guard("key " .. combo .. " (" .. id .. ")", actions[id]) end
        return
    end
    if Keys.Router then
        local ok, handled = pcall(Keys.Router, combo)
        if ok and handled then
            e:PreventAction()
            claimed[key] = true
            return
        elseif not ok then
            Log.Error("router key " .. combo .. ": " .. tostring(handled))
        end
    end
    if Keys.Observer and not e.Repeat then Log.Guard("key observer " .. combo, Keys.Observer, combo) end
end

function Keys.Start()
    Ext.Events.KeyInput:Subscribe(onKey)
end

return Keys
