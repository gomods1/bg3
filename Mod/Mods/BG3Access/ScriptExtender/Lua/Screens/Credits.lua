-- The credits (Game/Credits) as a list: each heading with its names ("Directed by: Swen Vincke").
-- Escape is the game's (closes them). Letters stay the game's too.
local Game = Ext.Require("Game/Credits.lua")
local Strings = Ext.Require("Core/Strings.lua")
local ListScreen = Ext.Require("Screens/ListScreen.lua")
local Controls = Ext.Require("Screens/Controls.lua")

local L = Strings.Get

local Credits = ListScreen.Extend()
Credits.Widgets = { Game.Widget }

function Credits.New(widget)
    return setmetatable(ListScreen.New(widget.name, L("screen_credits")), Credits)
end

function Credits:Build()
    local out = {}
    for _, c in ipairs(Game.Read()) do
        local names = #c.names > 0 and Strings.List(c.names) or nil
        local line = (c.heading and names) and L("label_value", { label = c.heading, value = names }) or c.heading or names
        out[#out + 1] = Controls.Text(line)
    end
    return out
end

return Credits
