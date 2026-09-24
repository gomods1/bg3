-- Activation ladder for UI elements (gate.md 5.5):
--  1. the element's bound ICommand, when it needs no CommandParameter (Execute(nil));
--  2. a cursor warp + click by the native bridge at a measured position, verified with IsMouseOver
--     before clicking. Needed for CustomEvent buttons: SE v32 cannot pass a string parameter to a
--     command (boxed values are converted to Lua strings both ways), and has no PointToScreen yet
--     (added upstream after v32), so positions come from ClickHints (fractions of the window).
local Ui = Ext.Require("Game/Ui.lua")
local Bridge = Ext.Require("Core/Bridge.lua")
local Log = Ext.Require("Core/Log.lua")

local Activate = {}

-- [widget][element] = { fx, fy }: centre of the element as a fraction of the client area, measured
-- on 2560x1600 (16:10). Wrong or stale hints fail safely: the hover check refuses the click.
local ClickHints = {
    Eula = { AcceptBtn = { 0.500, 0.931 }, ToSButton = { 0.097, 0.931 }, PrivacyButton = { 0.220, 0.931 } },
    SensitiveSettings = { NextButton = { 0.500, 0.931 } },
    GammaCalibration = { AcceptButton = { 0.500, 0.931 }, ResetButton = { 0.903, 0.931 } },
    MainMenu = { ModsButton = { 0.222, 0.655 }, OptionsButton = { 0.222, 0.715 }, CreditsButton = { 0.222, 0.759 } },
}

-- Small search around the hint, nearest first.
local OFFSETS = { { 0, 0 }, { 0, -0.012 }, { 0, 0.012 }, { -0.03, 0 }, { 0.03, 0 }, { 0, -0.025 }, { 0, 0.025 } }

local HOVER_WAIT_MS = 250 -- hover state follows a cursor warp within a few frames (measured: <600 ms)
local HOVER_TRIES = 4

local function clickVerified(widget, elName, onDone)
    local hint = ClickHints[widget] and ClickHints[widget][elName]
    if not hint then
        onDone(false, "no click position known")
        return
    end
    local i = 0
    local function try()
        i = i + 1
        if i > #OFFSETS then
            onDone(false, "the cursor could not reach it")
            return
        end
        local fx, fy = hint[1] + OFFSETS[i][1], hint[2] + OFFSETS[i][2]
        Bridge.Send(string.format("mouse move %.4f %.4f", fx, fy))
        local checks = 0
        local function check()
            checks = checks + 1
            local el = Ui.FindElement(widget, elName)
            if not el then
                onDone(false, "it is gone")
            elseif Ui.Prop(el, "IsMouseOver") == true then
                Bridge.Send("mouse click left")
                onDone(true)
            elseif checks < HOVER_TRIES then
                Ext.Timer.WaitForRealtime(HOVER_WAIT_MS, check)
            else
                try()
            end
        end
        Ext.Timer.WaitForRealtime(HOVER_WAIT_MS, check)
    end
    try()
end

-- entry: XAML index item { name=, command=, param= }. onDone(ok, reason) may run later.
function Activate.Element(widget, elName, entry, onDone)
    onDone = onDone or function() end
    local el = Ui.FindElement(widget, elName)
    if not el then
        onDone(false, "it is gone")
        return
    end
    if entry and entry.command and not entry.param then
        local cmd = Ui.Prop(el, "Command")
        if cmd then
            local ok, can = pcall(function() return cmd:CanExecute(nil) end)
            if ok and can == false then
                onDone(false, "unavailable")
                return
            end
            local okExec, err = pcall(function() cmd:Execute(nil) end)
            if okExec then
                onDone(true)
                return
            end
            Log.Error("Execute " .. elName .. ": " .. tostring(err))
        end
    end
    clickVerified(widget, elName, onDone)
end

return Activate
