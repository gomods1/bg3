-- Message boxes and confirmations (Game/MessageBox): title, text, then the action buttons.
-- Tab/Shift+Tab and Left/Right also move between the buttons.
local Game = Ext.Require("Game/MessageBox.lua")
local Speech = Ext.Require("Core/Speech.lua")
local Strings = Ext.Require("Core/Strings.lua")
local ListScreen = Ext.Require("Screens/ListScreen.lua")
local Controls = Ext.Require("Screens/Controls.lua")

local L = Strings.Get

local MessageBox = ListScreen.Extend()
MessageBox.DcTypes = { Game.DcType }

function MessageBox.New(widget)
    return setmetatable(ListScreen.New(widget.name, widget.name), MessageBox)
end

function MessageBox:Build()
    local box = Game.Read(self.widget)
    local controls = {}
    if not box then return controls end
    self.title = box.title or self.widget
    local widget = self.widget
    if box.checkbox then
        controls[#controls + 1] = Controls.CheckBox({
            label = box.checkbox.label or "?",
            get = function()
                local b = Game.Read(widget)
                return b and b.checkbox and b.checkbox.checked
            end,
            set = function(v) return Game.SetChecked(widget, v) end,
        })
    end
    for i, label in ipairs(box.actions) do
        controls[#controls + 1] = Controls.Button({
            label = label,
            activate = function(done) done(Game.Run(widget, i), "reason_unavailable") end,
        })
    end
    return controls
end

function MessageBox:ReadAll()
    local box = Game.Read(self.widget)
    if not box then return end
    local checkbox = box.checkbox and Strings.List({ box.checkbox.label or "?", L("role_checkbox"),
        L(box.checkbox.checked and "checked" or "not_checked") })
    Speech.Say(Strings.Sentences({ box.title, box.text, checkbox, L("message_buttons", { labels = Strings.List(box.actions) }) }))
end

function MessageBox:Announce()
    self:ReadAll()
end

function MessageBox:Activate()
    if not self:Current() then
        Speech.Say(L("choose_button_first"), { interrupt = true })
        return
    end
    ListScreen.Activate(self)
end

function MessageBox:Help()
    return { L("help_message_box") }
end

local NEXT = { RIGHT = true, TAB = true }
local PREV = { LEFT = true, ["SHIFT+TAB"] = true }

function MessageBox:OnKey(combo)
    if NEXT[combo] then self:Move(1) return true end
    if PREV[combo] then self:Move(-1) return true end
    return ListScreen.OnKey(self, combo)
end

return MessageBox
