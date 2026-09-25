-- The engine's pathfinding (client), used only to decide where to click and to describe routes:
-- the character itself always moves by the player's own clicks (CLAUDE.md, no magic movement).
-- Facts (SE v32, verified 2026-09-24): Ext.Level.BeginPathfindingImmediate(sourceEntity, {x,y,z})
-- + Ext.Level.FindPath(path) -> found; path.Checkpoints[] = { Position, Portal (entity for jumps,
-- ladders ... ; nil on a plain walk), Flags (bits not decoded yet: 0, 2, 4, 8, 32, 64, 128 seen) },
-- dense (about every 0.25 m). Release with Ext.Level.ReleasePath.
-- A new request has CanUseLadders and CanUsePortals false (IsPlayer true, StepHeight 0.6,
-- WorldClimbingHeight 2.1); they are writable before FindPath. With both false the nautiloid's
-- route to the bridge objective was not found at all; with both true it goes up two ladders
-- (portal entities with the Ladder component, items used by a click; verified 2026-09-24).
-- Targets must lie on walkable ground: a point off the AI grid fails at once (ErrorCause 1, no
-- search nodes; the map's area label "Arboleda Esmeralda" sits 29 m under the grove). Find snaps
-- the target to the nearest walkable height there (Ext.Level.GetHeightsAt: the AI grid's heights
-- in that column). Long routes are fine: 323 m, 1350 checkpoints in a few ms (grove -> ruins).
-- Closed doors the character cannot pass (the grove's portcullis) fail the search unless
-- CheckLockedDoors is false (verified 2026-09-24): ClosedDoorOnWay names them.
local Entities = Ext.Require("Game/Entities.lua")
local Timer = Ext.Require("Core/Timer.lua")

local Paths = {}

local DOOR_NEAR_ROUTE_METERS = 2.0

-- p moved to the walkable height nearest to it in its column (p itself when there is none).
function Paths.Snap(p)
    local ok, heights = pcall(Ext.Level.GetHeightsAt, p[1], p[3])
    if not ok or not heights then return p end
    local best
    for _, h in ipairs(heights) do
        if not best or math.abs(h - p[2]) < math.abs(best - p[2]) then best = h end
    end
    if not best then return p end
    return { p[1], best, p[3] }
end

-- Route from an entity (uuid) to a point (snapped to walkable ground): { found = bool,
-- points = { {x,y,z}, ... }, flags = { n, ... }, portals = { index of checkpoints that go through
-- a portal }, portalInfo = { [index] = { uuid, ladder = bool } } } or nil when no request was
-- possible. options.ignoreDoors: through closed doors too.
function Paths.Find(fromUuid, to, options)
    local source = Entities.Get(fromUuid)
    if not source then return nil end
    to = Paths.Snap(to)
    local ok, path = pcall(Ext.Level.BeginPathfindingImmediate, source, { to[1], to[2], to[3] })
    if not ok or not path then return nil end
    pcall(function()
        path.CanUseLadders = true
        path.CanUsePortals = true
        if options and options.ignoreDoors then path.CheckLockedDoors = false end
    end)
    local result = { found = false, points = {}, flags = {}, portals = {}, portalInfo = {} }
    local okFind, found = pcall(Ext.Level.FindPath, path)
    result.found = okFind and found == true
    if result.found then
        for i, c in ipairs(path.Checkpoints) do
            local p = c.Position
            result.points[i] = { p[1], p[2], p[3] }
            result.flags[i] = c.Flags
            if c.Portal then
                result.portals[#result.portals + 1] = i
                local okInfo, uuid, ladder = pcall(function()
                    return c.Portal.Uuid.EntityUuid, c.Portal.Ladder and true or false
                end)
                result.portalInfo[i] = { uuid = okInfo and uuid or nil, ladder = okInfo and ladder or false }
            end
        end
    end
    pcall(Ext.Level.ReleasePath, path)
    return result
end

-- When no route reaches the point but one through closed doors does: the uuid of the first door
-- on that route (the way is closed there); else nil.
function Paths.ClosedDoorOnWay(fromUuid, to)
    local route = Paths.Find(fromUuid, to, { ignoreDoors = true })
    if not route or not route.found then return nil end
    local best, bestIndex
    for _, e in ipairs(Ext.Entity.GetAllEntitiesWithComponent("IsDoor")) do
        local ok, uuid = pcall(function() return e.Uuid.EntityUuid end)
        local pos = ok and Entities.Position(uuid)
        if pos then
            for i, q in ipairs(route.points) do
                if bestIndex and i >= bestIndex then break end
                if Entities.Distance(pos, q) <= DOOR_NEAR_ROUTE_METERS then
                    best, bestIndex = uuid, i
                    break
                end
            end
        end
    end
    return best
end

-- Dangerous surfaces (2026-09-24: a route through the burning nautiloid wreck on the Risen Road
-- killed Tav, 1 HP). The engine's routes ignore surfaces, and path:UsePlayerWeighting() with the
-- character's influences copied in changed nothing (the same 25 fire points; the SE source adds
-- no surface cost). So the walker's own table decides: SurfacePathInfluences.PathInfluences
-- (Fire 40, Lava 700, WaterElectrified 100, PoisonCloud 70 ...) against the game's
-- DamagingSurfacesThreshold (ExtraData, 35); tiles read with Ext.Level.GetTileDebugInfo
-- (GroundSurface, CloudSurface).
local function dangerousSet(uuid)
    local set = {}
    local e = Entities.Get(uuid)
    local threshold = 35
    pcall(function() threshold = Ext.Stats.GetStatsManager().ExtraData["DamagingSurfacesThreshold"] or threshold end)
    pcall(function()
        for _, inf in ipairs(e.SurfacePathInfluences.PathInfluences) do
            if inf.Influence >= threshold then set[(inf.IsCloud and "cloud:" or "ground:") .. tostring(inf.SurfaceType)] = true end
        end
    end)
    return set
end

local function dangerAt(set, p)
    local ok, t = pcall(Ext.Level.GetTileDebugInfo, { p[1], p[2], p[3] })
    if not ok or not t then return nil end
    local ground, cloud = tostring(t.GroundSurface), tostring(t.CloudSurface)
    if set["ground:" .. ground] then return ground end
    if set["cloud:" .. cloud] then return cloud end
    return nil
end

-- A test for surfaces dangerous for character uuid: fn(p) -> surface type name or nil; nil when
-- nothing is dangerous for it.
function Paths.DangerTest(uuid)
    local set = dangerousSet(uuid)
    if next(set) == nil then return nil end
    return function(p) return dangerAt(set, p) end
end

-- The first route point (index >= from) on a surface dangerous for character uuid, and the
-- surface's type name ("Fire"); nil when the route is safe. When the character stands on such a
-- surface, the stretch the route starts in does not count: walking out is the way out. Only
-- then: Mira beside a burning patch on the nautiloid had a route through its first 1.5 m, and
-- letting that through set her on fire (2026-09-24, 8 damage).
function Paths.FirstDanger(uuid, points, from)
    local set = dangerousSet(uuid)
    if next(set) == nil then return nil end
    local i = from or 1
    local here = Entities.Position(uuid)
    if here and dangerAt(set, here) then
        while i <= #points and dangerAt(set, points[i]) do i = i + 1 end
    end
    for j = i, #points do
        local surface = dangerAt(set, points[j])
        if surface then return j, surface end
    end
    return nil
end

-- true when character uuid stands on a surface dangerous for it.
function Paths.StandsOnDanger(uuid)
    local here = Entities.Position(uuid)
    return here ~= nil and dangerAt(dangerousSet(uuid), here) ~= nil
end

-- A surface dangerous for character uuid within clearance meters of the straight line from a to
-- b (sampled every half meter, and clearance to either side): its type and the point; nil when
-- clear. The game walks nearly straight to a click on open ground, even across what the engine's
-- route bends round. Over the first NEAR_START meters only the line itself counts: a character
-- beside a fire would otherwise have no way out at all (Tav at a burning patch's edge, 2026-09-24).
local NEAR_START = 1.5
function Paths.DangerNearLine(uuid, a, b, clearance)
    local set = dangerousSet(uuid)
    if next(set) == nil then return nil end
    local dx, dz = b[1] - a[1], b[3] - a[3]
    local len = math.sqrt(dx * dx + dz * dz)
    if len < 0.01 then return nil end
    local ux, uz = dx / len, dz / len
    for d = 0, len, 0.5 do
        local cx, cy, cz = a[1] + ux * d, a[2] + (b[2] - a[2]) * d / len, a[3] + uz * d
        local sides = d < NEAR_START and { 0 } or { 0, clearance, -clearance }
        for _, side in ipairs(sides) do
            local q = Paths.Snap({ cx - uz * side, cy, cz + ux * side })
            local surface = dangerAt(set, q)
            if surface then return surface, q end
        end
    end
    return nil
end

-- The ground's material ("Grass", "Gravel", "WaterDeep"...) at the walkable height nearest p, or
-- nil (Ext.Level.GetTileDebugInfo Material; verified 2026-09-24 near the chapel: Stone terrace,
-- Gravel and Dirt road, Sand and WaterDeep of the beach, Grass).
function Paths.MaterialAt(p)
    local q = Paths.Snap(p)
    local ok, t = pcall(Ext.Level.GetTileDebugInfo, { q[1], q[2], q[3] })
    if not ok or not t then return nil end
    local m = tostring(t.Material)
    if m == "" or m == "None" then return nil end
    return m
end

-- The walkable point nearest target that a route from character uuid reaches, for a target no
-- route reaches (the goblin camp's quest marker behind the Blighted Village, the grove behind its
-- closed gate: "no route" is ErrorCause 1, the same as a target off the grid, and a failed request
-- leaves no closest point: ClosestFullTileIndex -1; verified 2026-09-24, client and server alike).
-- Candidates: rings round the target and the straight line back to the character, on tiles not
-- flagged WalkBlock, tried nearest the target first; the first one a route reaches wins. A failed
-- search takes about 26 ms (its horizon is 32000 nodes), so the tries are spread over frames
-- within SEARCH_BUDGET_MS each. onDone(point or nil). Returns a function that stops the search.
local RING_RADII = { 8, 16, 24, 32, 48, 64, 96, 128 }
local RING_DIRECTIONS = 12
local LINE_STEP = 10
local SEARCH_BUDGET_MS = 40
local MAX_TRIES = 150
local REACHED_METERS = 2.5 -- a route ending this close to a candidate reaches it

local function walkableHeights(x, z)
    local out = {}
    local ok, heights = pcall(Ext.Level.GetHeightsAt, x, z)
    for _, h in ipairs(ok and heights or {}) do
        local okTile, t = pcall(Ext.Level.GetTileDebugInfo, { x, h, z })
        local blocked = false
        for _, f in ipairs(okTile and t and t.Flags or {}) do
            if tostring(f) == "WalkBlock" then blocked = true break end
        end
        if not blocked then out[#out + 1] = h end
    end
    return out
end

function Paths.NearestReachable(uuid, target, onDone)
    local from = Entities.Position(uuid)
    if not from then onDone(nil) return function() end end
    local spots = {}
    for _, r in ipairs(RING_RADII) do
        for k = 0, RING_DIRECTIONS - 1 do
            local a = 2 * math.pi * k / RING_DIRECTIONS
            spots[#spots + 1] = { target[1] + math.sin(a) * r, target[3] + math.cos(a) * r }
        end
    end
    local total = Entities.Distance(from, target)
    for d = LINE_STEP, total, LINE_STEP do
        local f = d / total
        spots[#spots + 1] = { target[1] + (from[1] - target[1]) * f, target[3] + (from[3] - target[3]) * f }
    end
    local candidates = {}
    for _, xz in ipairs(spots) do
        for _, h in ipairs(walkableHeights(xz[1], xz[2])) do
            candidates[#candidates + 1] = { xz[1], h, xz[2], d = Entities.Distance({ xz[1], h, xz[2] }, target) + math.abs(h - target[2]) }
        end
    end
    table.sort(candidates, function(a, b) return a.d < b.d end)
    local stopped, i = false, 0
    local function tryMore()
        if stopped then return end
        local started = Ext.Utils.MonotonicTime()
        while Ext.Utils.MonotonicTime() - started < SEARCH_BUDGET_MS do
            i = i + 1
            local c = candidates[i]
            if not c or i > MAX_TRIES then onDone(nil) return end
            local p = { c[1], c[2], c[3] }
            local route = Paths.Find(uuid, p)
            local last = route and route.found and route.points[#route.points]
            if last and Entities.Distance(last, p) <= REACHED_METERS then onDone(last) return end
        end
        Timer.After(0, tryMore)
    end
    tryMore()
    return function() stopped = true end
end

-- Length of a route in meters (sum of the segments).
function Paths.Length(points)
    local d = 0
    for i = 2, #points do d = d + Entities.Distance(points[i - 1], points[i]) end
    return d
end

return Paths
