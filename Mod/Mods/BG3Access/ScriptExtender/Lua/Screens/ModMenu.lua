-- The mod menu (one key, config keys.menu): the commands available right now (Core/Commands),
-- what the player is doing first (combat, exploration), then the screen's and speech commands.
-- The screen in front can add its own commands with handler:Commands() -> { { label, run } }; they
-- come first.
--
-- It opens over whatever handler is in front (Router.PushModScreen) and gives it back before a
-- command runs, so "read the screen", "details" and "repeat" act on what the player was on, and
-- the last line spoken before the menu is what "repeat" repeats.
local Commands = Ext.Require("Core/Commands.lua")
local Keys = Ext.Require("Core/Keys.lua")
local Speech = Ext.Require("Core/Speech.lua")
local Strings = Ext.Require("Core/Strings.lua")
local ListScreen = Ext.Require("Screens/ListScreen.lua")
local Controls = Ext.Require("Screens/Controls.lua")

local L = Strings.Get

local ModMenu = ListScreen.Extend()
ModMenu.LetterJump = true

-- screen: the handler the menu opens over (may be nil); pop: gives the keys back to it.
function ModMenu.New(screen, pop)
    local self = setmetatable(ListScreen.New("(menu)", L("screen_menu")), ModMenu)
    self.screen, self.pop = screen, pop
    self.before = Speech.last
    return self
end

function ModMenu:Run(run)
    self.pop()
    Speech.last = self.before
    run()
end

function ModMenu:Build()
    local out = {}
    local own = self.screen and self.screen.Commands and self.screen:Commands() or {}
    for _, c in ipairs(own) do
        out[#out + 1] = Controls.Item({
            kind = "button",
            describe = function() return c.label end,
            activate = function() self:Run(c.run) end,
        })
    end
    for _, c in ipairs(Commands.Available()) do
        out[#out + 1] = Controls.Item({
            kind = "button",
            describe = function()
                local combo = Keys.CombosFor(c.id)[1]
                return Strings.List({ Commands.Label(c), combo and Strings.KeyName(combo) })
            end,
            activate = function() self:Run(function() Commands.Run(c) end) end,
        })
    end
    return out
end

function ModMenu:Help()
    return { L("help_menu") }
end

function ModMenu:OnKey(combo)
    if combo == "ESCAPE" then
        self.pop()
        Speech.Say(L("closed"), { interrupt = true })
        return true
    end
    return ListScreen.OnKey(self, combo)
end

return ModMenu
