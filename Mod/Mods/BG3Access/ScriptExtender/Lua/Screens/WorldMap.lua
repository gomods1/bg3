-- The world map (widget JournalMap, key M; also the journal's other tabs, which the mod reads
-- through its own Journal command). What a sighted player takes from the map, as lists:
--   where the party is (the area name),
--   the map's markers (quests, traders, characters, custom markers...) with compass direction
--   and distance: Enter closes the map and walks there (Exploration/Travel),
--   the waypoints: Enter travels there at once (the game's fast travel).
-- North is up on the map (Exploration/Direction.Compass). Escape is the game's (closes the map).
local Map = Ext.Require("Game/Map.lua")
local Entities = Ext.Require("Game/Entities.lua")
local Input = Ext.Require("Game/Input.lua")
local Travel = Ext.Require("Exploration/Travel.lua")
local Direction = Ext.Require("Exploration/Direction.lua")
local Notices = Ext.Require("Exploration/Notices.lua")
local Speech = Ext.Require("Core/Speech.lua")
local Strings = Ext.Require("Core/Strings.lua")
local Text = Ext.Require("Core/Text.lua")
local Timer = Ext.Require("Core/Timer.lua")
local ListScreen = Ext.Require("Screens/ListScreen.lua")
local Controls = Ext.Require("Screens/Controls.lua")

local L = Strings.Get

local WorldMap = ListScreen.Extend()
WorldMap.Widgets = { "JournalMap" }

local MAP_CLOSE_MS = 800 -- the map closes on a later frame; the walk starts after

function WorldMap.New(widget)
    return setmetatable(ListScreen.New(widget.name, L("screen_world_map")), WorldMap)
end

local function kindWords(m)
    local key = "marker_" .. tostring(m.type)
    return Strings.Has(key) and L(key) or L("marker_other")
end

-- "Entrada a las ruinas, objective, North-east, 84 meters"
local function markerLine(m)
    local me = Entities.Position(Entities.Controlled())
    local p = m.uuid and Entities.Position(m.uuid) or m.position
    return Strings.List({ Text.StripStop(m.name or "?"), kindWords(m), me and p and Direction.Compass(me, p),
        me and p and L("meters", { n = math.floor(Entities.Distance(me, p) + 0.5) }) })
end

local function goTo(marker)
    local m = { name = Text.StripStop(marker.name or "?"), uuid = marker.uuid, position = marker.position }
    local key = Input.ScancodeFor("UICancel")
    if key then Ext.Input.InjectKeyPress(key) end -- the game's own close
    Speech.Say(L("going_to", { name = m.name or "?" }), { interrupt = true })
    Timer.After(MAP_CLOSE_MS, function()
        local function done(ok, reason, detail)
            local text
            if ok and detail and detail.short then
                text = L("arrived_near", { name = m.name or "?", n = detail.short })
            elseif ok then
                text = L("arrived_at", { name = m.name or "?" })
            else
                text = Travel.FailureText(m.name or "?", reason, detail)
            end
            if text then Speech.Say(text) end
        end
        -- A marker with no character or object (an objective) may lie where no way goes yet:
        -- heading for it still brings the party as close as the ways allow.
        if m.uuid then Travel.Interact(m.uuid, done, m.position) else Travel.GoToward(m.position, done) end
    end)
end

local function markers()
    local me = Entities.Position(Entities.Controlled())
    local list = {}
    for _, m in ipairs(Map.Markers()) do
        if m.type ~= "CharacterParty" then list[#list + 1] = m end
    end
    if me then
        table.sort(list, function(a, b)
            local pa, pb = Map.TypeRank(a.type), Map.TypeRank(b.type)
            if pa ~= pb then return pa < pb end
            return Entities.Distance(me, a.position) < Entities.Distance(me, b.position)
        end)
    end
    return list
end

function WorldMap:Build()
    local out = { Controls.Text(Notices.WhereAmI()) }
    local list = markers()
    out[#out + 1] = Controls.Item({
        kind = "button",
        describe = function() return L("map_markers", { n = #list }) end,
        activate = function()
            self:Push(L("map_markers", { n = #list }), function()
                local items = {}
                for _, m in ipairs(markers()) do
                    items[#items + 1] = Controls.Item({
                        kind = "button",
                        describe = function() return markerLine(m) end,
                        activate = function() goTo(m) end,
                    })
                end
                return items
            end)
        end,
    })
    local waypoints = Map.Waypoints()
    out[#out + 1] = Controls.Item({
        kind = "button",
        describe = function() return L("map_waypoints", { n = #waypoints }) end,
        activate = function()
            self:Push(L("map_waypoints", { n = #waypoints }), function()
                local items = {}
                for i, w in ipairs(Map.Waypoints()) do
                    items[#items + 1] = Controls.Button({
                        label = w.name,
                        activate = function(done)
                            local ok = Map.GoToWaypoint(i)
                            if ok then Speech.Say(L("travelling_to", { name = w.name }), { interrupt = true }) end
                            done(ok, "reason_unavailable")
                        end,
                    })
                end
                return items
            end)
        end,
    })
    return out
end

function WorldMap:Help()
    local lines = ListScreen.Help(self)
    lines[#lines + 1] = L("help_world_map")
    return lines
end

return WorldMap
