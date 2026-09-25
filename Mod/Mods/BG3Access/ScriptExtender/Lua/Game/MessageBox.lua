-- Message boxes and confirmations: any widget whose data context is ls.DCMessageBox (e.g. widget
-- "Dialog_box"). TitleProperty/TextProperty are handles; Actions[i] = { Name handle, ActionCommand,
-- BoundEvent }. An action runs through the game's key for its BoundEvent, else its own command
-- (no parameter), so no click is needed.
-- Optional parts: a check box (CheckBoxProperty shown, CheckBoxLabelProperty handle,
-- CheckBoxValueProperty bool; e.g. "enable tutorials" at the start of character creation) and a
-- text input (InputBoxProperty shown, InputTextProperty, InputBoxMaxLengthProperty).
local Vm = Ext.Require("Game/Vm.lua")
local Input = Ext.Require("Game/Input.lua")
local Timer = Ext.Require("Core/Timer.lua")

local MessageBox = {}

MessageBox.DcType = "ls.DCMessageBox"

-- { title, text, actions = { label, ... }, checkbox = { label, checked }?, input = { text }? }
-- or nil when the box is gone.
function MessageBox.Read(widgetName)
    local dc = Vm.WidgetDc(widgetName)
    if not dc then return nil end
    local text = Vm.Text(dc, "TextProperty")
    -- A runtime string (the save overwrite question: "ResStr_...") resolves to the bare template
    -- "[1]": nothing to say.
    if text and text:match("^%[%d+%]%.?$") then text = nil end
    local out = { title = Vm.Text(dc, "TitleProperty"), text = text, actions = {} }
    if Vm.Get(dc, "CheckBoxProperty") == true then
        out.checkbox = { label = Vm.Text(dc, "CheckBoxLabelProperty"), checked = Vm.Get(dc, "CheckBoxValueProperty") == true }
    end
    if Vm.Get(dc, "InputBoxProperty") == true then
        out.input = { text = tostring(Vm.Get(dc, "InputTextProperty") or "") }
    end
    for i, a in ipairs(Vm.List(dc, "Actions")) do
        out.actions[i] = Vm.Text(a, "Name") or ("#" .. i)
    end
    return out
end

-- Runs action i (1-based). Returns ok. The action's bound key first (UIAccept -> Enter,
-- injected): the long-rest question ("¿Quieres dar el día por terminado?", 2026-09-24) ignored its
-- "Sí" ActionCommand (executed, nothing happened) but went on with the game's Enter. The
-- tutorials question at the start of character creation did the opposite (the injected Enter did
-- nothing, "Aceptar"'s command closed it, 2026-09-24): when the same box is still up a moment
-- after the key, its command runs. Actions without a bound key run their command (verified: the
-- quit confirmation).
local KEY_FALLBACK_MS = 700

local function boxKey(widgetName)
    local box = MessageBox.Read(widgetName)
    return box and ((box.title or "") .. "|" .. (box.text or "")) or nil
end

function MessageBox.Run(widgetName, i)
    local a = Vm.List(Vm.WidgetDc(widgetName), "Actions")[i]
    if not a then return false end
    local event = Vm.Enum(a, "BoundEvent")
    local key = event and event ~= "" and event ~= "None" and Input.ScancodeFor(event)
    if key then
        local before = boxKey(widgetName)
        Ext.Input.InjectKeyPress(key)
        Timer.After(KEY_FALLBACK_MS, function()
            if before and boxKey(widgetName) == before then
                local still = Vm.List(Vm.WidgetDc(widgetName), "Actions")[i]
                if still then Vm.Run(still, "ActionCommand", nil) end
            end
        end)
        return true
    end
    return Vm.Run(a, "ActionCommand", nil)
end

-- Sets the check box. Returns ok.
function MessageBox.SetChecked(widgetName, value)
    local dc = Vm.WidgetDc(widgetName)
    if not dc then return false end
    return pcall(function() dc:SetProperty("CheckBoxValueProperty", value == true) end)
end

return MessageBox
