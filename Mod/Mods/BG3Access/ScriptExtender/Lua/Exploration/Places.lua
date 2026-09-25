-- Places (mod menu): the named places of this area the party has been to ("Estanque sagrado, you
-- are here", "El Hueco, North-east, 40 meters"), nearest first, with the game's own names
-- (Game/Places). Enter walks with Travel to where the party entered the place (a walkable spot
-- inside it) and stops once inside. A blind player's way back to somewhere seen before, which the
-- map offers a sighted player.
local Places = Ext.Require("Game/Places.lua")
local Notification = Ext.Require("Game/Notification.lua")
local Entities = Ext.Require("Game/Entities.lua")
local Travel = Ext.Require("Exploration/Travel.lua")
local Direction = Ext.Require("Exploration/Direction.lua")
local Speech = Ext.Require("Core/Speech.lua")
local Strings = Ext.Require("Core/Strings.lua")
local ListScreen = Ext.Require("Screens/ListScreen.lua")
local Controls = Ext.Require("Screens/Controls.lua")

local L = Strings.Get

local PlacesScreen = ListScreen.Extend()

-- Opens the list once the server has answered. open(screen) shows it (Router.OpenModScreen).
function PlacesScreen.Show(open, onClose)
    Places.Visited(function(places)
        local self = setmetatable(ListScreen.New("(places)", L("screen_places")), PlacesScreen)
        self.onClose = onClose
        self.places = places
        open(self)
    end)
end

local function line(place, here)
    if place.current then return Strings.List({ place.name, L("place_you_are_here") }) end
    local meters = here and math.floor(Entities.Distance(here, place.position) + 0.5)
    return Strings.List({ place.name, here and Direction.Compass(here, place.position), meters and L("meters", { n = meters }) })
end

function PlacesScreen:Walk(place)
    Speech.Say(L("going_to", { name = place.name }), { interrupt = true })
    if self.onClose then self.onClose() end
    -- Inside the place is there: the area name the game shows is the place's.
    local function inside() return Notification.AreaName() == place.name end
    Travel.GoTo(place.position, function(ok, reason, detail)
        local text = ok and L("arrived_at", { name = place.name }) or Travel.FailureText(place.name, reason, detail)
        if text then Speech.Say(text) end
    end, inside)
end

function PlacesScreen:Build()
    local here = Entities.Position(Entities.Controlled())
    local list = {}
    for _, p in ipairs(self.places) do list[#list + 1] = p end
    if here then
        table.sort(list, function(a, b)
            if a.current ~= b.current then return a.current end
            return Entities.Distance(here, a.position) < Entities.Distance(here, b.position)
        end)
    end
    local out = {}
    for _, place in ipairs(list) do
        out[#out + 1] = Controls.Item({
            kind = "button",
            describe = function() return line(place, Entities.Position(Entities.Controlled())) end,
            activate = function() self:Walk(place) end,
        })
    end
    if #out == 0 then out[1] = Controls.Text(L("places_none")) end
    return out
end

function PlacesScreen:Help()
    local lines = ListScreen.Help(self)
    lines[#lines + 1] = L("help_places")
    return lines
end

return PlacesScreen
