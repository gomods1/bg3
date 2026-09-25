-- Main menu (widget MainMenu, gui::DCMainMenu). Button IsEnabled values are bindings (they read as
-- nil), so availability is computed from the view model the way MainMenu.xaml binds it:
--   LoadGameButton.IsEnabled = ExistingSaves.Count > 0
--   ContinueButton.Visibility = HasSaveGames (collapsed otherwise), IsEnabled = SelectedSave != null
local Vm = Ext.Require("Game/Vm.lua")

local MainMenu = {}

MainMenu.Widget = "MainMenu"

local RULES = {
    LoadGameButton = function(dc) return #Vm.List(dc, "ExistingSaves") > 0 end,
    ContinueButton = function(dc) return Vm.Get(dc, "SelectedSave") ~= nil end,
}

-- true/false for buttons whose availability is known from the view model, nil otherwise.
function MainMenu.Available(elName)
    local rule = RULES[elName]
    if not rule then return nil end
    local dc = Vm.WidgetDc(MainMenu.Widget)
    if dc == nil then return nil end
    return rule(dc)
end

return MainMenu
