-- Main menu (widget MainMenu, gui::DCMainMenu): its buttons as a list. Static texts are dropped:
-- hidden panels carry labels that cannot be visibility-checked.
local Game = Ext.Require("Game/MainMenu.lua")
local Strings = Ext.Require("Core/Strings.lua")
local Generic = Ext.Require("Screens/Generic.lua")
local ListScreen = Ext.Require("Screens/ListScreen.lua")

local MainMenu = ListScreen.Extend(Generic)
MainMenu.Widgets = { Game.Widget }

function MainMenu.New(widget, page)
    local opts = { title = Strings.Get("screen_main_menu"), buttonsOnly = true, availability = Game.Available }
    return setmetatable(Generic.New(widget, page, opts), MainMenu)
end

return MainMenu
