-- The game's input bindings (client), read from the input manager (Ext.Input.GetInputManager()).
-- Facts (SE v32, game 4.1.1.7398727, verified 2026-09-24):
--  * InputScheme.RawToBinding[raw].Bindings[] = { InputIndex = event id, Binding = { InputId (raw
--    input name, e.g. "pageup", "kp_1", "left2"), DeviceId (0 keyboard, 1 mouse, 65534 controller),
--    Modifiers (bitmask: Ctrl/Shift/Alt/Gui) }, BindingIndex (slot: 0 primary, 1 secondary) }.
--  * InputScheme.InputBindings[player] is a LegacyArray whose elements after the first read as
--    garbage in SE v32: do not use it.
--  * InputDefinitions[event id] = { EventName, EventDesc (translated string; its handle is the label
--    the key binding options show) }.
local Strings = Ext.Require("Core/Strings.lua")

local Input = {}

local DEVICE_KEYBOARD, DEVICE_MOUSE = 0, 1

local CACHE_MS = 500
local cache = { at = -CACHE_MS, byEvent = {} }
local descToEvent = nil

local function manager()
    local ok, im = pcall(Ext.Input.GetInputManager)
    if ok then return im end
    return nil
end

local function modifierList(mods)
    local out = {}
    for _, name in ipairs({ "Ctrl", "Shift", "Alt", "Gui" }) do
        local ok, set = pcall(function() return mods[name] end)
        if ok and set == true then out[#out + 1] = name end
    end
    return out
end

-- event id -> { { input = "pageup", device = 0|1, modifiers = { "Ctrl", ... }, slot = n }, ... },
-- keyboard and mouse only, sorted by slot. Rebuilt at most every CACHE_MS (bindings can change).
local function bindingsByEvent()
    local now = Ext.Timer.MonotonicTime()
    if now - cache.at < CACHE_MS then return cache.byEvent end
    local byEvent = {}
    local im = manager()
    local raw = im and im.InputScheme.RawToBinding
    for i = 1, (raw and #raw or 0) do
        for _, desc in ipairs(raw[i].Bindings) do
            local b = desc.Binding
            local device = tonumber(b.DeviceId)
            if device == DEVICE_KEYBOARD or device == DEVICE_MOUSE then
                local list = byEvent[desc.InputIndex] or {}
                list[#list + 1] = { input = tostring(b.InputId), device = device, modifiers = modifierList(b.Modifiers), slot = desc.BindingIndex }
                byEvent[desc.InputIndex] = list
            end
        end
    end
    for _, list in pairs(byEvent) do
        table.sort(list, function(a, b) return (a.slot or 0) < (b.slot or 0) end)
    end
    cache.at, cache.byEvent = now, byEvent
    return byEvent
end

-- Keyboard/mouse bindings of an input event id (see bindingsByEvent).
function Input.Bindings(eventId)
    return bindingsByEvent()[eventId] or {}
end

-- Event id whose description handle is `handle` (the label of a key binding options row), or nil.
function Input.EventForLabel(handle)
    if descToEvent == nil then
        descToEvent = {}
        local im = manager()
        for id, def in pairs(im and im.InputDefinitions or {}) do
            local ok, h = pcall(function() return def.EventDesc.Handle.Handle end)
            if ok and h then descToEvent[tostring(h)] = id end
        end
    end
    return descToEvent[tostring(handle)]
end

-- Event id by event name ("QuickSave"), or nil.
function Input.EventByName(name)
    local im = manager()
    for id, def in pairs(im and im.InputDefinitions or {}) do
        if tostring(def.EventName) == name then return id end
    end
    return nil
end

-- Spoken name of the first keyboard binding of an input event ("QuickSave" -> "F5"); for an
-- event bound only to the mouse, the mouse input's name ("CameraToggleMouseRotate" -> "botón
-- central del ratón": a loading hint read the event names, 2026-09-24); nil when neither.
function Input.KeyName(eventName)
    local id = Input.EventByName(eventName)
    local mouse = nil
    for _, b in ipairs(id and Input.Bindings(id) or {}) do
        if b.device == DEVICE_KEYBOARD then return Strings.InputName(b.input, b.modifiers) end
        if b.device == DEVICE_MOUSE and not mouse and Strings.Has("input_mouse_" .. b.input) then
            mouse = Strings.Get("input_mouse_" .. b.input)
        end
    end
    return mouse
end

-- Game text with input placeholders ("pulsa [IE_QuickSave]", in loading hints and tutorials) as
-- the game shows them: the key's name. Unknown events keep the event name.
function Input.FillPlaceholders(text)
    if not text then return nil end
    return (text:gsub("%[IE_([%w_]+)%]", function(name) return Input.KeyName(name) or name end))
end

-- Raw input names whose SDL scancode name (Ext.Input.InjectKeyPress) is not just the upper case.
local RAW_TO_SCANCODE = { enter = "RETURN", hyphen = "MINUS", backtick = "GRAVE" }

-- SDL scancode name of the first unmodified keyboard binding of an input event ("UIAccept" ->
-- "RETURN"), for pressing the game's own key; nil when the event has none.
function Input.ScancodeFor(eventName)
    local id = Input.EventByName(eventName)
    for _, b in ipairs(id and Input.Bindings(id) or {}) do
        if b.device == DEVICE_KEYBOARD and #b.modifiers == 0 then
            return RAW_TO_SCANCODE[b.input] or b.input:upper()
        end
    end
    return nil
end

return Input
