-- View-model (data context) access helpers (client). The Game/<Screen> accessors use these; screen
-- handlers never read view-model properties themselves.
-- Facts (SE v32, verified 2026-09-24): view models are fully readable with GetProperty; commands
-- take a Noesis object or nil as parameter (a Lua string cannot be boxed); many commands are
-- deferred, so their effect shows on a later frame. Engine objects expire at the end of the tick.
local Ui = Ext.Require("Game/Ui.lua")
local Loca = Ext.Require("Game/Loca.lua")
local Log = Ext.Require("Core/Log.lua")
local Text = Ext.Require("Core/Text.lua")
local Input = Ext.Require("Game/Input.lua")

local Vm = {}

function Vm.Get(obj, name)
    if not obj then return nil end -- not "== nil": that runs __eq, which throws on expired objects
    local ok, v = pcall(function() return obj:GetProperty(name) end)
    if ok then return v end
    return nil
end

-- true when a and b are the same engine object. Never compare engine objects with nil through
-- ==: SE's __eq throws on nil and on expired objects ("expected a light C++ object, got nil").
function Vm.Same(a, b)
    if not (a and b) then return false end
    local ok, same = pcall(function() return a == b end)
    return ok and same == true
end

-- A property holding a loca handle, as speakable text.
function Vm.Text(obj, name)
    return Loca.Text(Vm.Get(obj, name))
end

-- A context-translated string (ls.VMContextTransString: Text template with "[n]" slots, Params[]
-- with Text) as plain text, or nil. Used by the combat log, notifications, level-up features.
function Vm.ContextText(ctx)
    if not ctx then return nil end
    local template = tostring(Vm.Get(ctx, "Text") or "")
    if template:find("^h%x+g%x+g") then template = Loca.Get(template) or "" end -- a handle
    if template == "" then return nil end
    local params = Vm.List(ctx, "Params")
    local s = template:gsub("%[(%d+)%]", function(n)
        local p = params[tonumber(n)]
        return p and tostring(Vm.Get(p, "Text") or "") or ""
    end)
    return Text.Clean(Input.FillPlaceholders(s))
end

-- Enum-valued property as its name ("ComboBox"), or nil.
function Vm.Enum(obj, name)
    local v = Vm.Get(obj, name)
    if v == nil then return nil end
    return tostring(v)
end

-- A collection property as a Lua array (1-based) of engine objects, valid this tick only.
function Vm.List(obj, name)
    local coll = Vm.Get(obj, name)
    local out = {}
    if not coll then return out end
    local ok, n = pcall(function() return #coll end)
    for i = 1, (ok and n or 0) do out[i] = coll[i] end
    return out
end

-- Data context of an open top-level widget.
function Vm.WidgetDc(widgetName)
    local w = Ui.FindWidget(widgetName)
    return w and Vm.Get(w, "DataContext") or nil
end

-- true / false, or nil when the command is missing or CanExecute fails.
function Vm.CanExecute(cmd, param)
    if not cmd then return nil end
    local ok, can = pcall(function() return cmd:CanExecute(param) end)
    if ok then return can end
    return nil
end

-- Executes a command; returns ok. Logs failures with a label.
function Vm.Execute(cmd, param, label)
    if not cmd then return false end
    local ok, err = pcall(function() cmd:Execute(param) end)
    if not ok then Log.Error("Execute " .. tostring(label) .. ": " .. tostring(err)) end
    return ok
end

-- Executes a command property of obj (e.g. the DC's "NextComboItemCommand") with a parameter.
function Vm.Run(obj, commandName, param)
    local cmd = Vm.Get(obj, commandName)
    if not cmd then
        Log.Error("command " .. commandName .. " missing")
        return false
    end
    if Vm.CanExecute(cmd, param) == false then return false end
    return Vm.Execute(cmd, param, commandName)
end

return Vm
