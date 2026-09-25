-- Map markers (client): the world map's markers, readable any time through CurrentPlayer (the
-- Minimap widget's data context), without opening the map.
-- Facts (verified 2026-09-24 on the nautiloid): CurrentPlayer.WorldMap (ls.WorldMap).Markers[] of
-- ls.MapMarker { Type (Player, QuestMarker, CharacterNeutral, ...), Name (handle), WorldPos {x, z},
-- Height (y), GameObject (VM with EntityUUID, empty for quest markers), QuestViews[] }.
local Vm = Ext.Require("Game/Vm.lua")
local Player = Ext.Require("Game/Player.lua")

local Map = {}

-- { { type, name, position = {x, y, z}, uuid? }, ... } without the player's own marker.
-- The game's list can hold one marker several times (five "Arboleda Esmeralda" location markers
-- at one spot, seen 2026-09-24 in the grove): one entry per type, name and position.
local function markerKey(kind, name, pos)
    return string.format("%s|%s|%.0f|%.0f", tostring(kind), tostring(name), pos[1], pos[2])
end

-- Order of marker types in the mod's lists: objectives and the places a player looks for first;
-- characters (a grove full of tieflings, the enemies of a fight) after them; the party last.
local TYPE_RANK = { QuestMarker = 1, Trader = 2, Custom = 3, Waypoint = 4, Secret = 5, CharacterParty = 99 }

function Map.TypeRank(markerType)
    return TYPE_RANK[markerType] or 9
end

function Map.Markers()
    local out, seen = {}, {}
    for _, m in ipairs(Vm.List(Vm.Get(Player.Current(), "WorldMap"), "Markers")) do
        local kind = Vm.Enum(m, "Type")
        local pos = Vm.Get(m, "WorldPos")
        if kind ~= "Player" and pos then
            local uuid = Vm.Get(Vm.Get(m, "GameObject"), "EntityUUID")
            -- A quest marker without a name of its own is named after its quest
            -- ("Encuentra una cura."; QuestViews[].Quest.Title).
            local name = Vm.Text(m, "Name")
            if not name then
                local view = Vm.List(m, "QuestViews")[1]
                name = view and Vm.Text(Vm.Get(view, "Quest"), "Title")
            end
            local key = markerKey(kind, name, pos)
            if not seen[key] then
                seen[key] = true
                out[#out + 1] = {
                    type = kind,
                    name = name,
                    position = { pos[1], Vm.Get(m, "Height") or 0, pos[2] },
                    uuid = (uuid and uuid ~= "") and uuid or nil,
                }
            end
        end
    end
    return out
end

-- Waypoints the party can travel to (fast travel; in camp also "Abandonar el campamento"):
-- CurrentPlayer.Waypoints[] (per region: RegionName, WaypointList[] of VMs with a Name handle),
-- travelled to with any DC's GoToWaypoint(waypoint) (verified 2026-09-24: left camp for the chapel
-- entrance). { { name } } in the game's order.
local function waypoints()
    local out = {}
    for _, region in ipairs(Vm.List(Player.Current(), "Waypoints")) do
        for _, w in ipairs(Vm.List(region, "WaypointList")) do out[#out + 1] = w end
    end
    return out
end

function Map.Waypoints()
    local out = {}
    for i, w in ipairs(waypoints()) do out[i] = { name = Vm.Text(w, "Name") or "?" } end
    return out
end

-- Travels to waypoint i (a loading screen follows). Returns ok.
function Map.GoToWaypoint(i)
    local w = waypoints()[i]
    if not w then return false end
    return Vm.Run(Vm.WidgetDc("HotBar"), "GoToWaypoint", w)
end

return Map
