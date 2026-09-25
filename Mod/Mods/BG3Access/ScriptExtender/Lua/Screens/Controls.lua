-- Controls: the items of a list screen (Screens/ListScreen). A control is a table with
--   kind           "text" | "button" | "option" (summary counts, help)
--   Describe()     -> string spoken on focus: label, role, value, state
--   Activate()     optional, Enter/Space
--   Change(delta, fine)  optional, Left/Right (delta 1 or -1; fine = Shift held); nil means the
--                  key goes to the game
--   Details()      optional -> string, longer description (details key)
-- Controls keep names and indexes, never engine objects (those expire at the end of the tick).
local Options = Ext.Require("Game/Options.lua")
local Speech = Ext.Require("Core/Speech.lua")
local Timer = Ext.Require("Core/Timer.lua")
local Strings = Ext.Require("Core/Strings.lua")

local L = Strings.Get

local Controls = {}

-- How long to wait before reading a value back after a (deferred) game command.
local READBACK_MS = 150

-- Speaks fn()'s text after a (deferred) game command had time to apply.
function Controls.SayLater(fn)
    Ext.Timer.WaitForRealtime(READBACK_MS, function()
        local text = fn()
        if text then Speech.Say(text, { interrupt = true }) end
    end)
end

-- Speaks read() once it differs from before (a deferred game command applied), or after
-- CHANGE_WAIT_MS whatever it is then. read() -> string or nil; before is read()'s text taken
-- before the command.
local CHANGE_POLL_MS, CHANGE_WAIT_MS = 100, 1500
function Controls.SayWhenChanged(read, before)
    local started = Ext.Timer.MonotonicTime()
    local function poll()
        local now = read()
        if (now ~= nil and now ~= before) or Ext.Timer.MonotonicTime() - started >= CHANGE_WAIT_MS then
            if now then Speech.Say(now, { interrupt = true }) end
            return
        end
        Timer.After(CHANGE_POLL_MS, poll)
    end
    Timer.After(CHANGE_POLL_MS, poll)
end

-- A control from functions: opts { kind = "text"|"button"|"option", describe = fn -> string,
-- activate = fn?, change = fn(delta, fine)?, details = fn -> string? }. Screen-specific controls
-- (character creation choices, abilities, skills) are built with this.
function Controls.Item(opts)
    return {
        kind = opts.kind or "text",
        Describe = opts.describe,
        Activate = opts.activate,
        Change = opts.change,
        Details = opts.details,
    }
end

function Controls.Text(text)
    return { kind = "text", Describe = function() return text end }
end

-- opts: { label = string, activate = function(done(ok, reasonKey)), available = function() -> bool }
function Controls.Button(opts)
    local c = { kind = "button" }
    function c.Describe()
        local unavailable = opts.available and opts.available() == false
        return Strings.List({ opts.label, L("role_button"), unavailable and L("unavailable") })
    end
    function c.Activate()
        opts.activate(function(ok, reasonKey)
            if not ok then
                Speech.Say(L("could_not_activate", { label = opts.label, reason = L(reasonKey or "reason_unavailable") }))
            end
        end)
    end
    return c
end

local function valueText(v)
    if type(v) == "number" then return Strings.Number(v, 2) end
    return tostring(v)
end

-- A check box backed by functions: opts { label, get = function() -> bool, set = function(bool) -> ok }.
-- Enter/Space toggle; Right checks, Left unchecks.
function Controls.CheckBox(opts)
    local c = { kind = "option" }
    local function state() return L(opts.get() and "checked" or "not_checked") end
    function c.Describe()
        return Strings.List({ opts.label, L("role_checkbox"), state() })
    end
    local function set(value)
        if not opts.set(value) then
            Speech.Say(L("cannot_change"), { interrupt = true })
            return
        end
        Ext.Timer.WaitForRealtime(READBACK_MS, function() Speech.Say(state(), { interrupt = true }) end)
    end
    function c.Activate() set(not opts.get()) end
    function c.Change(delta) set(delta > 0) end
    return c
end

-- Value part of an option row, as spoken after a change.
local function rowValue(r)
    if r.kind == "ComboBox" then return r.value or "?" end
    if r.kind == "TickBox" then return L(r.checked and "checked" or "not_checked") end
    if r.value ~= nil then return valueText(r.value) end
    return nil
end

local function describeRow(r)
    local label = r.label or "?"
    local parts
    if r.kind == "ComboBox" then
        parts = { L("label_value", { label = label, value = r.value or "?" }), L("role_list"),
            r.position and r.count and L("position", { i = r.position, n = r.count }) }
    elseif r.kind == "TickBox" then
        parts = { label, L("role_checkbox"), rowValue(r) }
    elseif r.kind == "Slider" then
        parts = { label, L("role_slider"), rowValue(r) or "?" }
    elseif r.kind == "EditBox" then
        parts = { label, L("role_edit"), r.value and valueText(r.value) }
    elseif r.kind == "Button" then
        parts = { label, L("role_button") }
    elseif r.kind == "String" then
        parts = { label }
    elseif r.kind == "KeyBinding" then
        local keys = {}
        for _, b in ipairs(r.bindings or {}) do keys[#keys + 1] = Strings.InputName(b.input, b.modifiers) end
        parts = { L("label_value", { label = label, value = #keys > 0 and Strings.List(keys) or L("not_bound") }) }
    else
        parts = { label, r.kind }
    end
    parts[#parts + 1] = not r.enabled and L("unavailable") or nil
    return Strings.List(parts)
end

local function readBack(widgetName, index)
    Ext.Timer.WaitForRealtime(READBACK_MS, function()
        local r = Options.Row(widgetName, index)
        if r then Speech.Say(rowValue(r) or describeRow(r), { interrupt = true }) end
    end)
end

-- A row of Game/Options on widget widgetName. Headers (String rows) are plain text; list buttons
-- are buttons; the rest are options (kind "option").
function Controls.OptionRow(widgetName, index)
    local r0 = Options.Row(widgetName, index)
    local kind = r0 and r0.kind
    local c = { kind = (kind == "String" and "text") or (kind == "Button" and "button") or (kind == "KeyBinding" and "text") or "option" }
    function c.Describe()
        local r = Options.Row(widgetName, index)
        return r and describeRow(r) or L("option_gone")
    end
    function c.Details()
        local r = Options.Row(widgetName, index)
        return r and r.description
    end
    -- Headers are text; key bindings are read-only for now (rebinding: RequestKeybindingChange, todo).
    if kind == "String" or kind == "KeyBinding" then return c end
    function c.Activate()
        if not Options.Press(widgetName, index) then
            Speech.Say(c.Describe(), { interrupt = true })
            return
        end
        if kind ~= "Button" then readBack(widgetName, index) end
    end
    if kind ~= "Button" then
        function c.Change(delta, fine)
            if not Options.Step(widgetName, index, delta, fine) then
                Speech.Say(L("cannot_change"), { interrupt = true })
                return
            end
            readBack(widgetName, index)
        end
    end
    return c
end

return Controls
