-- New game difficulty (widget DMSettings, gui::DCDMSettings). The game's own Left/Right change the
-- preset; the selected one is PresetList.SelectedItem, a gui::VMPreset with Title/Description
-- handles and IsHonour.
local Ui = Ext.Require("Game/Ui.lua")
local Vm = Ext.Require("Game/Vm.lua")

local Difficulty = {}

Difficulty.Widget = "DMSettings"

-- { title, description, honour } or nil.
function Difficulty.Selected()
    local list = Ui.FindElement(Difficulty.Widget, "PresetList")
    local sel = list and Vm.Get(list, "SelectedItem")
    if sel == nil then return nil end
    return {
        title = Vm.Text(sel, "Title"),
        description = Vm.Text(sel, "Description"),
        honour = Vm.Get(sel, "IsHonour") == true,
    }
end

return Difficulty
