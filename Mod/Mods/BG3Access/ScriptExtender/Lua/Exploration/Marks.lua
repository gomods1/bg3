-- The player's marks (mod menu): "Mark this spot" keeps where the controlled character stands,
-- named after the area and the nearest thing ("Bosque, junto a Señal"); "Your marks" lists them
-- nearest first (Exploration/PlaceList: Enter walks there), Delete removes one. A sighted player's
-- custom map markers need a click on the map; these are kept with the save (Server/Marks).
local Game = Ext.Require("Game/Marks.lua")
local Entities = Ext.Require("Game/Entities.lua")
local Interactables = Ext.Require("Game/Interactables.lua")
local Notification = Ext.Require("Game/Notification.lua")
local PlaceList = Ext.Require("Exploration/PlaceList.lua")
local Speech = Ext.Require("Core/Speech.lua")
local Strings = Ext.Require("Core/Strings.lua")
local ListScreen = Ext.Require("Screens/ListScreen.lua")

local L = Strings.Get

local Marks = ListScreen.Extend(PlaceList)

local NAME_NEAR = 8 -- meters: a thing this close names the mark
local NAME_MAX_DY = 3

-- The nearest thing (not a character: they move) to p within NAME_NEAR, or nil.
local function nearestThing(p)
    local best, bestD = nil, math.huge
    for _, o in ipairs(Interactables.Near(p, NAME_NEAR, NAME_MAX_DY)) do
        local d = Entities.Distance(o.position, p)
        if o.category ~= "character" and o.name and d < bestD then best, bestD = o, d end
    end
    return best
end

function Marks.MarkHere()
    local p = Entities.Position(Entities.Controlled())
    if not p then return end
    local area, thing = Notification.AreaName(), nearestThing(p)
    local name = (area and thing and L("mark_name_near", { area = area, thing = thing.name }))
        or area or (thing and thing.name) or L("mark_unnamed")
    Game.Add(name, p, function() Speech.Say(L("mark_added", { name = name }), { interrupt = true }) end)
end

local function entriesOf(marks)
    local out = {}
    for _, m in ipairs(marks) do out[#out + 1] = { name = m.name, position = m.position, markId = m.id } end
    return out
end

function Marks.Show(open, onClose)
    Game.List(function(marks)
        if #marks == 0 then
            Speech.Say(L("marks_none"), { interrupt = true })
            return
        end
        local self = setmetatable(PlaceList.New("(marks)", L("screen_marks"), entriesOf(marks), onClose, open), Marks)
        open(self)
    end)
end

-- Delete: removes the mark in focus.
function Marks:OnKey(combo)
    if combo == "DEL" and #self.levels == 0 then -- the Delete key's SDL name (logged)
        local c = self:Current()
        local e = c and c.entry
        if not e then return true end
        Game.Remove(e.markId, function(marks)
            Speech.Say(L("mark_removed", { name = e.name }), { interrupt = true })
            if #marks == 0 then
                self:Close("")
                return
            end
            self.entries = PlaceList.New("(marks)", self.title, entriesOf(marks)).entries
            self.index = math.min(self.index, #self.entries)
            self:Refresh()
        end)
        return true
    end
    return PlaceList.OnKey(self, combo)
end

function Marks:Help()
    local lines = ListScreen.Help(self)
    lines[#lines + 1] = L("help_marks")
    return lines
end

return Marks
