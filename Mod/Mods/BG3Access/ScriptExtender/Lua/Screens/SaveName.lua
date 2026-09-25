-- The new save's popup (widget SaveGamePopup, SaveGameInputSaveNameDialog.xaml): the game's own
-- texts and buttons (Screens/Generic), plus the description, typed with the mod's text entry
-- (Screens/TextEntry) and set in the game's box SaveName, whose text the Guardar button saves
-- with (DoSaveWithName with the box's Text). The box does not read back: the typed text is kept.
local Generic = Ext.Require("Screens/Generic.lua")
local Ui = Ext.Require("Game/Ui.lua")
local Speech = Ext.Require("Core/Speech.lua")
local Strings = Ext.Require("Core/Strings.lua")
local Controls = Ext.Require("Screens/Controls.lua")
local ListScreen = Ext.Require("Screens/ListScreen.lua")
local TextEntry = Ext.Require("Screens/TextEntry.lua")

local L = Strings.Get

local SaveName = ListScreen.Extend(Generic)
SaveName.Widgets = { "SaveGamePopup" }

local MAX_LENGTH = 40

function SaveName.New(widget, page)
    local self = Generic.New(widget, page)
    self.typed = nil
    return setmetatable(self, SaveName)
end

function SaveName:SetText(text)
    local box = Ui.FindAllByName(Ui.FindWidget(self.widget), "SaveName")[1]
    if not box then return false end
    local ok = pcall(function() box:SetProperty("Text", text) end)
    if ok then self.typed = text end
    return ok
end

function SaveName:Build()
    local out = Generic.Build(self)
    table.insert(out, 1, Controls.Item({
        kind = "button",
        describe = function() return L("cc_section", { section = L("save_description"), value = self.typed or L("cc_name_default") }) end,
        activate = function()
            self:BeginEntry(TextEntry.New({
                label = L("save_description"),
                text = self.typed or "",
                maxLength = MAX_LENGTH,
                onDone = function(text)
                    if not text then return end
                    if text == "" or not self:SetText(text) then
                        Speech.Say(L("could_not_activate", { label = L("save_description"), reason = L("reason_unavailable") }), { interrupt = true })
                        return
                    end
                    Speech.Say(L("cc_section", { section = L("save_description"), value = text }), { interrupt = true })
                end,
            }))
        end,
    }))
    return out
end

return SaveName
