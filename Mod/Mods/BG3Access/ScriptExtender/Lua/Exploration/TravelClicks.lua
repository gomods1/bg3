-- Where a trip clicks next (Exploration/Travel): the route (Game/SafeRoute: the engine's, round
-- dangerous surfaces where it can) turned into ground points to click, farthest first, and the
-- verified clicks on them. A click is accepted only on walkable ground of the route, reachable
-- from the walker without crossing a dangerous surface (see ClickFirst).
local Activate = Ext.Require("Game/Activate.lua")
local Entities = Ext.Require("Game/Entities.lua")
local Paths = Ext.Require("Game/Paths.lua")
local SafeRoute = Ext.Require("Game/SafeRoute.lua")
local Bridge = Ext.Require("Core/Bridge.lua")
local Strings = Ext.Require("Core/Strings.lua")

local TravelClicks = {}

local MIN_STEP_METERS = 1.0
local MAX_STEP_METERS = 12.0
local LOOK_AHEAD_METERS = 6.0
local CANDIDATE_SPACING = 2.0
local FAR_STEP_METERS = 25.0 -- fallback clicks further along the route (see candidates)
local FAR_CANDIDATE_SPACING = 3.0
local MAX_FAR_CANDIDATES = 5
local MAX_CANDIDATES = 10
local ARRIVE_METERS = 2.5   -- GoTo: close enough to a point
local DOOR_USE_NEAR = 3.0   -- a shut door on the only way is tried from this close
local DOOR_STOP_METERS = 1.5 -- the walk up to it stops this far before it
-- A click is on the route when the ground it picks lies this close to any route point: the
-- route's heights do not always follow the terrain (measured on the way to the grove: aimed at a
-- point 1.9 m above the ground there, the picking hit the path 4.5 m further along).
local ON_ROUTE_METERS = 2.0
local ON_ROUTE_MAX_DY = 3.0
-- The engine's route to picked ground ends at its walkable height (Paths snaps the target): more
-- than this above or below the picked point means the picking hit something not walkable (a ledge).
local REACH_MAX_DY = 1.0
-- Meters kept between the straight line to a click and any dangerous surface (the game's walk to a
-- click on open ground is nearly straight; characters are about half a meter wide).
local CLICK_CLEARANCE = 1.0

-- A surface type ("Fire") as spoken: the mod's own name when it has one, else a general word.
function TravelClicks.SurfaceName(surface)
    local key = "surface_" .. tostring(surface)
    return Strings.Has(key) and Strings.Get(key) or Strings.Get("surface_dangerous")
end

-- Clickable points of route.points[1..limit], farthest first: only the first MAX_STEP_METERS
-- that stay on screen (a winding route can come back into view far away, behind walls:
-- measured), then fallbacks further on. Returns out, info = { visibleMeters, heading = {dx, dz},
-- route = the points up to limit } (the heading turns the camera when needed).
local function clickablePoints(me, route, limit)
    local from = Entities.Position(me)
    local visible, walked = 1, 0
    while visible < limit do
        local nextPoint = route.points[visible + 1]
        local d = Entities.Distance(route.points[visible], nextPoint)
        if walked + d > MAX_STEP_METERS or not Activate.SafeProjection(nextPoint) then break end
        walked = walked + d
        visible = visible + 1
    end
    local out, last = {}, nil
    for i = visible, 2, -1 do
        local p = route.points[i]
        if Entities.Distance(p, from) < MIN_STEP_METERS or #out >= MAX_CANDIDATES then break end
        if not last or Entities.Distance(p, last) >= CANDIDATE_SPACING then
            out[#out + 1] = p
            last = p
        end
    end
    -- Fallbacks, tried after those: the route further on, nearest first, wherever it shows on
    -- screen. Something above the route can hide all of its start (the stone arch over the grove
    -- stairs: every pick hit its top, 2026-09-24) while the stairs beyond it are in view.
    local along, fallbacks = walked, 0
    last = nil
    for i = visible + 1, limit do
        along = along + Entities.Distance(route.points[i - 1], route.points[i])
        if along > FAR_STEP_METERS or fallbacks >= MAX_FAR_CANDIDATES then break end
        local p = route.points[i]
        if Activate.SafeProjection(p) and (not last or Entities.Distance(p, last) >= FAR_CANDIDATE_SPACING) then
            out[#out + 1] = p
            last = p
            fallbacks = fallbacks + 1
        end
    end
    local ahead, along2 = route.points[limit], 0
    for i = 2, limit do
        along2 = along2 + Entities.Distance(route.points[i - 1], route.points[i])
        if along2 >= LOOK_AHEAD_METERS then ahead = route.points[i] break end
    end
    local routePoints = {}
    for i = 1, limit do routePoints[i] = route.points[i] end
    return out, { visibleMeters = walked, heading = { ahead[1] - from[1], ahead[3] - from[3] }, route = routePoints }
end

-- A step aside when every click on the way was refused for a dangerous surface near the line to
-- it (the route keeps off surfaces, but the game's straight walk to a click can cut closer):
-- points DETOUR_RADII meters away at
-- DETOUR_ANGLES from the direction of the danger, each with a safe route from the walker; the one
-- nearest the target wins. The next step plans again from there, so the walk works along the
-- edge of the surface; the no-progress rule ends it where there is no way round.
local DETOUR_RADII = { 5, 8, 12 }
local DETOUR_ANGLES = { 60, -60, 90, -90, 120, -120 }

local function detour(me, target, dangerPoint)
    local from = Entities.Position(me)
    local base = math.atan(dangerPoint[1] - from[1], dangerPoint[3] - from[3])
    local best, bestRoute, bestScore
    for _, r in ipairs(DETOUR_RADII) do
        for _, deg in ipairs(DETOUR_ANGLES) do
            local a = base + math.rad(deg)
            local w = { from[1] + math.sin(a) * r, from[2], from[3] + math.cos(a) * r }
            local route = Paths.Find(me, w)
            local last = route and route.found and route.points[#route.points]
            if last and Entities.Distance(last, w) <= ARRIVE_METERS and not Paths.FirstDanger(me, route.points, 2) then
                local score = Entities.Distance(last, target)
                if not bestScore or score < bestScore then best, bestRoute, bestScore = last, route, score end
            end
        end
    end
    return best, bestRoute
end

-- What to click next toward target: points (farthest first), nil, info; or nil, reason, info?,
-- detail? when there is nothing to click (no route: the closed door on the way, when that is
-- why; a dangerous surface ahead with no way round). The route goes round dangerous surfaces
-- where it can (Game/SafeRoute); where it cannot, the clicks stop before the surface.
local function candidates(me, target)
    local route = SafeRoute.Find(me, target)
    if not route or not route.found or #route.points == 0 then
        local door = Paths.ClosedDoorOnWay(me, target)
        if not door then return nil, "reason_no_path" end
        -- A shut door is the only way: walk up to it and try it, as a player clicks a door (a
        -- key in the pack unlocks it: Priestess Gut's chapel door with her key, 2026-09-25).
        local doorPos, here = Entities.Position(door), Entities.Position(me)
        local detail = { door = Entities.Name(door) or "?", doorUuid = door }
        if doorPos and here and Entities.Distance(here, doorPos) <= DOOR_USE_NEAR then
            return nil, "door_to_open", nil, detail
        end
        local through = Paths.Find(me, target, { ignoreDoors = true })
        local limit = 0
        for i, q in ipairs(through and through.found and through.points or {}) do
            if doorPos and Entities.Distance(q, doorPos) <= DOOR_STOP_METERS then break end
            limit = i
        end
        if limit == 0 then return nil, "door_to_open", nil, detail end
        local out, info = clickablePoints(me, through, limit)
        if #out > 0 then return out, nil, info end
        return nil, "reason_door_closed", nil, detail
    end
    local limit = #route.points
    if route.portals[1] then limit = math.max(1, route.portals[1] - 1) end
    local danger, surface = Paths.FirstDanger(me, route.points, 2)
    if danger and danger - 1 < limit then limit = math.max(1, danger - 1) end
    local out, info = clickablePoints(me, route, limit)
    info.danger = danger and TravelClicks.SurfaceName(surface) or nil
    if route.portals[1] and (not danger or route.portals[1] < danger) then info.portal = route.portalInfo[route.portals[1]] end
    if #out > 0 then return out, nil, info end
    if danger then return nil, "reason_surface", info, { surface = TravelClicks.SurfaceName(surface) } end
    return nil, route.portals[1] and "reason_portal" or "reason_no_path", info
end

-- Tries GroundClick on each point in order; onDone(ok, reasonKey, blocker). The first door found
-- on the way is reported when no point could be clicked, as { uuid, point }; so is the trip's own
-- target (targetUuid), even when it is a character (a body to loot).
-- The route starts at the character's feet: ground picked near its first MIN_STEP_METERS would
-- not move the character (measured on the grove stairs: the rock hid the stairs ahead and the
-- picking hit the ground beside Tav), so only the route beyond that counts. The picked ground must
-- also be walkable from here (the engine's own route ends on it): a rock ledge over the stairs lay
-- within the height tolerance of the route, and clicks on it did not move Tav (2026-09-24).
-- The way to the click must be safe too: the game walks its own path to the clicked point, and
-- a trip's route that bent round a burning patch still had Tav walk straight through it to the
-- next click (Risen Road, 2026-09-24: Tav died). A click is accepted only when the route from the
-- walker to it crosses no dangerous surface and the straight line to it keeps CLICK_CLEARANCE
-- from one. The last danger that refused a click is kept for the trip's report and detour.
local refusedFor = nil -- { surface, point }

local function reachableGround(g)
    local walker = Entities.Controlled()
    local route = Paths.Find(walker, g)
    local last = route and route.found and route.points[#route.points]
    if not last then return false end
    if Entities.Distance(last, g) > ON_ROUTE_METERS or math.abs(last[2] - g[2]) > REACH_MAX_DY then return false end
    local i, surface = Paths.FirstDanger(walker, route.points, 2)
    if i then
        refusedFor = { surface = surface, point = route.points[i] }
        return false
    end
    -- Standing in fire, every line out starts in it: the route alone decides then.
    if Paths.StandsOnDanger(walker) then return true end
    local here = Entities.Position(walker)
    local near, point = nil, nil
    if here then near, point = Paths.DangerNearLine(walker, here, g, CLICK_CLEARANCE) end
    if near then
        refusedFor = { surface = near, point = point }
        return false
    end
    return true
end

local function onRoute(route)
    if not route then return nil end
    return function(g)
        local along = 0
        for i, p in ipairs(route) do
            if i > 1 then along = along + Entities.Distance(route[i - 1], p) end
            if along >= MIN_STEP_METERS and Entities.Distance(g, p) <= ON_ROUTE_METERS
                and math.abs(g[2] - p[2]) <= ON_ROUTE_MAX_DY then
                return reachableGround(g)
            end
        end
        return false
    end
end

local function clickFirst(points, onDone, targetUuid, route, i, blocker)
    i = i or 1
    Activate.GroundClick(points[i], function(ok, reason, onObject)
        Bridge.Log(string.format("travel: ground click %d/%d at %.1f,%.1f,%.1f: %s%s", i, #points,
            points[i][1], points[i][2], points[i][3], ok and "ok" or tostring(reason),
            onObject and (" (" .. tostring(Entities.Name(onObject)) .. ")") or ""))
        -- Only a door is "used" on the way (the trip's own target aside): characters are not (the
        -- click lands on the character's own body just ahead of it, measured; clicking a party
        -- member would select them), nor ladders and passages (at the top of a ladder just
        -- climbed the trip clicked it again; next to the worg pens' way out it tried to use that
        -- passage), nor containers (a shelf beside the way was opened as if it blocked it: the
        -- worg pens, 2026-09-24). The route itself says when to take a ladder or a passage.
        if onObject and not blocker and (onObject == targetUuid or Entities.IsDoor(onObject)) then
            blocker = { uuid = onObject, point = points[i] }
        end
        if ok or i >= #points then
            onDone(ok, reason, not ok and blocker or nil)
        else
            clickFirst(points, onDone, targetUuid, route, i + 1, blocker)
        end
    end, onRoute(route))
end


TravelClicks.MIN_STEP_METERS = MIN_STEP_METERS
TravelClicks.ARRIVE_METERS = ARRIVE_METERS
TravelClicks.ClickablePoints = clickablePoints
TravelClicks.Detour = detour
TravelClicks.Candidates = candidates
TravelClicks.ClickFirst = clickFirst

-- The dangerous surface that refused a click since the last call ({ surface, point }), or nil;
-- forgets it.
function TravelClicks.TakeRefused()
    local r = refusedFor
    refusedFor = nil
    return r
end

return TravelClicks
