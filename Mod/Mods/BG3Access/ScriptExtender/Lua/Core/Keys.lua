-- Mod key handling through SE's KeyInput event (client). A handled key is prevented, which makes
-- SE's SDL_PollEvent hook swallow it before the game sees it (verify per key and per UI state).
-- Keys injected with Ext.Input.InjectKeyPress do not pass through KeyInput.
-- Order: global bindings first, then the screen router (Keys.Router, set by the bootstrap).
local Log = Ext.Require("Core/Log.lua")
local Bridge = Ext.Require("Core/Bridge.lua")

local Keys = {}

Keys.LogAllKeys = false
Keys.Router = nil -- function(combo) -> handled
local bindings = {} -- "MODS+KEY" -> { fn = function, name = string }
local claimed = {} -- scancode name -> true while a claimed press is held (its release is swallowed too)

local function comboName(key, mods)
    local parts = {}
    local m = tostring(mods or "")
    if m:find("Ctrl") then parts[#parts + 1] = "CTRL" end
    if m:find("Shift") then parts[#parts + 1] = "SHIFT" end
    if m:find("Alt") then parts[#parts + 1] = "ALT" end
    parts[#parts + 1] = tostring(key)
    return table.concat(parts, "+")
end

-- combo: "F10", "CTRL+F10", "SHIFT+GRAVE" (SDL scancode names, see SDLScanCode in ExtIdeHelpers)
function Keys.Bind(combo, name, fn)
    bindings[combo:upper()] = { fn = fn, name = name }
end

function Keys.Start()
    Ext.Events.KeyInput:Subscribe(function(e)
        local key = tostring(e.Key)
        local combo = comboName(e.Key, e.Modifiers)
        if Keys.LogAllKeys then
            Bridge.Log(string.format("key %s %s%s", combo, e.Pressed and "down" or "up", e.Repeat and " repeat" or ""))
        end
        if not e.Pressed then
            if claimed[key] then
                claimed[key] = nil
                e:PreventAction()
            end
            return
        end
        local b = bindings[combo]
        if b then
            e:PreventAction()
            claimed[key] = true
            if not e.Repeat then Log.Guard("key " .. combo .. " (" .. b.name .. ")", b.fn) end
            return
        end
        if Keys.Router then
            local ok, handled = pcall(Keys.Router, combo)
            if ok and handled then
                e:PreventAction()
                claimed[key] = true
            elseif not ok then
                Log.Error("router key " .. combo .. ": " .. tostring(handled))
            end
        end
    end)
end

return Keys
