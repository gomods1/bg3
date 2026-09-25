-- "Where am I" (mod menu): the area's name, then what a sighted player takes in at a glance: the
-- ground underfoot, which way the camera faces (the lists' "ahead" is away from the camera), the
-- directions one can walk from here, and the people close by. It said only the area's name
-- before ("Santuario destrozado", 2026-09-24).
local Notification = Ext.Require("Game/Notification.lua")
local Entities = Ext.Require("Game/Entities.lua")
local Paths = Ext.Require("Game/Paths.lua")
local Camera = Ext.Require("Game/Camera.lua")
local Direction = Ext.Require("Exploration/Direction.lua")
local Explore = Ext.Require("Exploration/Explore.lua")
local Strings = Ext.Require("Core/Strings.lua")

local L = Strings.Get

local WhereAmI = {}

local OPEN_REACHES = { 15, 6 } -- meters walked toward each direction to call it open: outdoors,
                               -- then indoors (the sanctum's halls: nothing open at 15 m)
local PEOPLE_RADIUS = 20  -- meters
local PEOPLE_NAMED = 3    -- the nearest named; the rest counted

-- Living characters outside the party within PEOPLE_RADIUS, nearest first: { names }.
local function people(here)
    local found = {}
    for _, e in ipairs(Ext.Entity.GetAllEntitiesWithComponent("ClientCharacter")) do
        local ok, uuid = pcall(function() return e.Uuid.EntityUuid end)
        local p = ok and Entities.Position(uuid)
        local name = p and Entities.Name(uuid)
        if name and not Entities.IsPartyMember(uuid) and not Entities.IsDead(uuid) then
            local d = Entities.Distance(p, here)
            if d <= PEOPLE_RADIUS then found[#found + 1] = { name = name, d = d } end
        end
    end
    table.sort(found, function(a, b) return a.d < b.d end)
    local names = {}
    for i, f in ipairs(found) do names[i] = f.name end
    return names
end

local function peopleWords(names)
    if #names == 0 then return nil end
    if #names <= PEOPLE_NAMED then return L("where_people", { names = Strings.List(names) }) end
    local first = {}
    for i = 1, PEOPLE_NAMED do first[i] = names[i] end
    return L("where_people_more", { names = Strings.List(first), n = #names - PEOPLE_NAMED })
end

function WhereAmI.Text()
    local area = Notification.AreaName()
    local parts = { area and L("you_are_in", { name = area }) or L("area_unknown") }
    local here = Entities.Position(Entities.Controlled())
    if not here then return Strings.Sentences(parts) end
    local ground = Paths.MaterialAt(here)
    if ground and Strings.Has("material_" .. ground) then
        parts[#parts + 1] = L("where_ground", { ground = L("material_" .. ground) })
    end
    local _, forward = Camera.GroundAxes()
    local facing = forward and Direction.Compass(here, { here[1] + forward[1], here[2], here[3] + forward[2] })
    if facing then parts[#parts + 1] = L("where_facing", { dir = facing }) end
    local open, reach = {}, nil
    for _, r in ipairs(OPEN_REACHES) do
        open, reach = Explore.OpenDirections(r), r
        if #open > 0 then break end
    end
    parts[#parts + 1] = #open > 0 and L("where_open", { n = reach, dirs = Strings.List(open) }) or L("where_closed", { n = reach })
    parts[#parts + 1] = peopleWords(people(here))
    return Strings.Sentences(parts)
end

return WhereAmI
