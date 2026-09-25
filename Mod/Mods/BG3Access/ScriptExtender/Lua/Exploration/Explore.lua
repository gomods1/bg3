-- Explore (mod menu): walking in a compass direction, the way a sighted player heads toward the
-- unknown. Eight directions (north = +z on the world map, east = +x: checked against the map's
-- markers 2026-09-24); each says how far the character can really walk that way (the engine's
-- route to a point up to REACH meters off, a little to either side when straight ahead is blocked).
-- Enter walks there with Travel (verified clicks along the route) and then names what came into
-- range (the Farther list before and after). Needed because places with no marker cannot be picked
-- from any list (the grove gate from the chapel, 2026-09-24).
local Paths = Ext.Require("Game/Paths.lua")
local Entities = Ext.Require("Game/Entities.lua")
local Travel = Ext.Require("Exploration/Travel.lua")
local Nearby = Ext.Require("Exploration/Nearby.lua")
local Speech = Ext.Require("Core/Speech.lua")
local Strings = Ext.Require("Core/Strings.lua")
local ListScreen = Ext.Require("Screens/ListScreen.lua")
local Controls = Ext.Require("Screens/Controls.lua")

local L = Strings.Get

local Explore = ListScreen.Extend()

local REACH = { 30, 22, 15, 8 }        -- meters tried, farthest first
local SIDE_ANGLES = { 0, 20, -20, 40, -40 } -- degrees off the chosen direction
local ARRIVE_SLACK = 3                  -- the route must end this close to the aimed point
local MAX_DETOUR = 2.5                  -- a route longer than this times the distance is not "that way"
local MAX_NEW_NAMES = 6
-- Terrain words: materials sampled along each direction (every TERRAIN_STEP meters up to
-- TERRAIN_REACH), the most common ones said when they cover TERRAIN_SHARE of the samples.
local TERRAIN_STEP, TERRAIN_REACH, TERRAIN_SHARE, TERRAIN_WORDS = 3, 30, 0.3, 2

local DIRECTIONS = {
    { key = "compass_north", x = 0, z = 1 }, { key = "compass_north_east", x = 1, z = 1 },
    { key = "compass_east", x = 1, z = 0 }, { key = "compass_south_east", x = 1, z = -1 },
    { key = "compass_south", x = 0, z = -1 }, { key = "compass_south_west", x = -1, z = -1 },
    { key = "compass_west", x = -1, z = 0 }, { key = "compass_north_west", x = -1, z = 1 },
}

function Explore.New(onClose)
    local self = setmetatable(ListScreen.New("(explore)", L("screen_explore")), Explore)
    self.onClose = onClose
    return self
end

-- The farthest walkable point toward direction d: point, route length; or nil.
local function reachable(d)
    local me = Entities.Controlled()
    local from = Entities.Position(me)
    if not from then return nil end
    local len = math.sqrt(d.x * d.x + d.z * d.z)
    local base = math.atan(d.x / len, d.z / len)
    for _, reach in ipairs(REACH) do
        for _, deg in ipairs(SIDE_ANGLES) do
            local a = base + math.rad(deg)
            local p = { from[1] + math.sin(a) * reach, from[2], from[3] + math.cos(a) * reach }
            local route = Paths.Find(me, p)
            local last = route and route.found and route.points[#route.points]
            if last and Entities.Distance(last, p) <= ARRIVE_SLACK and Paths.Length(route.points) <= reach * MAX_DETOUR then
                return last, Paths.Length(route.points)
            end
        end
    end
    return nil
end

-- The compass directions (their words) in which a route of about reach meters leads straight
-- away (no sideways tries: a quick look, for Where am I).
function Explore.OpenDirections(reach)
    local me = Entities.Controlled()
    local from = Entities.Position(me)
    local out = {}
    if not from then return out end
    for _, d in ipairs(DIRECTIONS) do
        local len = math.sqrt(d.x * d.x + d.z * d.z)
        local p = { from[1] + d.x / len * reach, from[2], from[3] + d.z / len * reach }
        local route = Paths.Find(me, p)
        local last = route and route.found and route.points[#route.points]
        if last and Entities.Distance(last, p) <= ARRIVE_SLACK and Paths.Length(route.points) <= reach * MAX_DETOUR then
            out[#out + 1] = L(d.key)
        end
    end
    return out
end

-- "grava y tierra": what the ground is like toward d, in the mod's words for the materials it
-- names (Strings "material_<Name>"); nil when nothing stands out.
local function terrain(d)
    local from = Entities.Position(Entities.Controlled())
    if not from then return nil end
    local len = math.sqrt(d.x * d.x + d.z * d.z)
    local counts, total = {}, 0
    for r = TERRAIN_STEP, TERRAIN_REACH, TERRAIN_STEP do
        local m = Paths.MaterialAt({ from[1] + d.x / len * r, from[2], from[3] + d.z / len * r })
        if m then
            counts[m] = (counts[m] or 0) + 1
            total = total + 1
        end
    end
    local ranked = {}
    for m, n in pairs(counts) do
        if n / total >= TERRAIN_SHARE and Strings.Has("material_" .. m) then ranked[#ranked + 1] = { m = m, n = n } end
    end
    table.sort(ranked, function(a, b) return a.n > b.n end)
    local words = {}
    for i = 1, math.min(#ranked, TERRAIN_WORDS) do words[i] = L("material_" .. ranked[i].m) end
    if #words == 0 then return nil end
    return #words == 1 and words[1] or L("terrain_two", { a = words[1], b = words[2] })
end

-- What matters most first when new things come into range (barrels last).
local CATEGORY_ORDER = { character = 1, trap = 2, door = 3, container = 4, loot = 5, other = 6 }

local function farEntries(onResult)
    Nearby.GatherFar(function(entries)
        local byUuid = {}
        for _, e in ipairs(entries) do byUuid[e.uuid] = e end
        onResult(byUuid)
    end)
end

-- "Lae'zel, Puerta, 3 Barril de madera": new entries by category, repeated names counted.
local function newThings(before, after)
    local fresh = {}
    for uuid, e in pairs(after) do
        if not before[uuid] then fresh[#fresh + 1] = e end
    end
    table.sort(fresh, function(a, b)
        local ca, cb = CATEGORY_ORDER[a.category] or 9, CATEGORY_ORDER[b.category] or 9
        if ca ~= cb then return ca < cb end
        return (a.name or "") < (b.name or "")
    end)
    local names, counts = {}, {}
    for _, e in ipairs(fresh) do
        local name = e.name or "?"
        if not counts[name] then names[#names + 1] = name end
        counts[name] = (counts[name] or 0) + 1
    end
    local out = {}
    for i = 1, math.min(#names, MAX_NEW_NAMES) do
        local n = counts[names[i]]
        out[i] = n > 1 and L("count_of", { n = n, name = names[i] }) or names[i]
    end
    return out
end

function Explore:Walk(d)
    local target = reachable(d)
    if not target then
        Speech.Say(L("explore_blocked", { direction = L(d.key) }), { interrupt = true })
        return
    end
    farEntries(function(before)
        Speech.Say(L("explore_going", { direction = L(d.key) }), { interrupt = true })
        if self.onClose then self.onClose() end
        Travel.GoTo(target, function(ok, reason, detail)
            if not ok then
                local text = Travel.FailureText(L(d.key), reason, detail)
                if text then Speech.Say(text) end
                return
            end
            farEntries(function(after)
                local fresh = newThings(before, after)
                Speech.Say(#fresh > 0 and L("explore_new", { names = Strings.List(fresh) }) or L("explore_nothing_new"))
            end)
        end)
    end)
end

function Explore:Build()
    local out = {}
    for _, d in ipairs(DIRECTIONS) do
        out[#out + 1] = Controls.Item({
            kind = "button",
            describe = function()
                local _, meters = reachable(d)
                local ground = terrain(d)
                if not meters then return Strings.List({ L(d.key), L("explore_no_way"), ground }) end
                return Strings.List({ L(d.key), L("explore_meters", { n = math.floor(meters + 0.5) }), ground })
            end,
            activate = function() self:Walk(d) end,
        })
    end
    return out
end

function Explore:Help()
    local lines = ListScreen.Help(self)
    lines[#lines + 1] = L("help_explore")
    return lines
end

return Explore
