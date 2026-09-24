-- Message boxes and confirmations (data context ls.DCMessageBox, e.g. widget "Dialog_box"):
-- TitleProperty/TextProperty handles, Actions[i] = { Name handle, ActionCommand, BoundEvent }.
-- Actions run through their own command (no parameter), so no click is needed.
local Ui = Ext.Require("Game/Ui.lua")
local Speech = Ext.Require("Core/Speech.lua")
local Text = Ext.Require("Core/Text.lua")

local MessageBox = {}
MessageBox.__index = MessageBox

function MessageBox.New(widget)
    local self = setmetatable({}, MessageBox)
    self.widget = widget.name
    self.index = 0
    return self
end

function MessageBox:Dc()
    return Ui.Prop(Ui.FindWidget(self.widget), "DataContext")
end

function MessageBox:Actions()
    local dc = self:Dc()
    local actions = dc and Ui.Prop(dc, "Actions")
    local out = {}
    if actions then
        for i = 1, #actions do
            out[#out + 1] = { label = Text.Clean(Ui.Loca(Ui.Prop(actions[i], "Name"))) or ("action " .. i), i = i }
        end
    end
    return out
end

function MessageBox:ReadAll()
    local dc = self:Dc()
    if not dc then return end
    local parts = {}
    parts[#parts + 1] = Text.Clean(Ui.Loca(Ui.Prop(dc, "TitleProperty")))
    parts[#parts + 1] = Text.Clean(Ui.Loca(Ui.Prop(dc, "TextProperty")))
    local labels = {}
    for _, a in ipairs(self:Actions()) do labels[#labels + 1] = a.label end
    parts[#parts + 1] = "Buttons: " .. table.concat(labels, ", ")
    local s = {}
    for _, p in ipairs(parts) do if p then s[#s + 1] = p end end
    Speech.Say(table.concat(s, ". "))
end

function MessageBox:Open()
    self:ReadAll()
end

function MessageBox:Move(delta)
    local actions = self:Actions()
    if #actions == 0 then return end
    self.index = math.max(1, math.min(#actions, self.index + delta))
    Speech.Say(actions[self.index].label .. ", button", { interrupt = true })
end

function MessageBox:Activate()
    local dc = self:Dc()
    local actions = dc and Ui.Prop(dc, "Actions")
    local a = actions and actions[self.index]
    if not a then Speech.Say("Choose a button with the arrows first") return end
    local cmd = Ui.Prop(a, "ActionCommand")
    if cmd then cmd:Execute(nil) end
end

function MessageBox:OnKey(combo)
    if combo == "DOWN" or combo == "RIGHT" or combo == "TAB" then self:Move(1) return true end
    if combo == "UP" or combo == "LEFT" or combo == "SHIFT+TAB" then self:Move(-1) return true end
    if combo == "RETURN" or combo == "SPACE" or combo == "KP_ENTER" then self:Activate() return true end
    return false
end

return MessageBox
