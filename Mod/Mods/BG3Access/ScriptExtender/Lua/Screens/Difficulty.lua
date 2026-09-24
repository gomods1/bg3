-- New game difficulty (widget DMSettings, view model gui::DCDMSettings). The game's own Left/Right
-- change the preset; we announce the selected preset (PresetList.SelectedItem, a gui::VMPreset with
-- Title/Description handles and IsHonour) whenever it changes. Up/Down/Enter use the generic list.
local Ui = Ext.Require("Game/Ui.lua")
local Speech = Ext.Require("Core/Speech.lua")
local Text = Ext.Require("Core/Text.lua")
local Generic = Ext.Require("Screens/Generic.lua")

local Difficulty = setmetatable({}, { __index = Generic })
Difficulty.__index = Difficulty

function Difficulty.New(widget, page)
    local self = Generic.New(widget, page, "Choose difficulty")
    setmetatable(self, Difficulty)
    self.lastPreset = nil
    return self
end

function Difficulty:Selected()
    local list = Ui.FindElement(self.widget, "PresetList")
    local sel = list and Ui.Prop(list, "SelectedItem")
    if not sel then return nil end
    local title = Ui.Loca(Ui.Prop(sel, "Title"))
    local desc = Text.Clean(Ui.Loca(Ui.Prop(sel, "Description")))
    return title, desc, Ui.Prop(sel, "IsHonour") == true
end

function Difficulty:Open()
    local title, desc, honour = self:Selected()
    self.lastPreset = title
    Speech.Say(string.format("Choose difficulty. %s%s. %s. Left and right arrows change it.",
        title or "?", honour and ", Honour mode: one save, deleted if the party dies" or "", desc or ""))
end

function Difficulty:Tick()
    local title, desc, honour = self:Selected()
    if title and title ~= self.lastPreset then
        self.lastPreset = title
        Speech.Say(string.format("%s%s. %s", title,
            honour and ", Honour mode: one save, deleted if the party dies" or "", desc or ""), { interrupt = true })
    end
end

return Difficulty
