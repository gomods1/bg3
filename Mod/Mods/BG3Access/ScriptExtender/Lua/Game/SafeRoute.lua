-- Routes that keep off dangerous surfaces. The engine's routes ignore surfaces (Game/Paths), and
-- it plans only from the walker's own position, so a way round a burning patch is planned here on
-- the engine's own AI grid: tiles read with Ext.Level.GetHeightsAt / GetTileDebugInfo, whose Flags
-- mark what a character cannot walk (WalkBlock: walls, rocks, cliffs; SlopeBlock: too steep;
-- WalkBlockItem: crates...), and whose surfaces say where it burns (verified 2026-09-24 on the
-- Risen Road: Tav in a gully whose only way north was a fire patch from wall to wall; the engine
-- routed through it, the grid showed the way round). Reading a 41 x 41 m square takes about 1 ms.
-- The plan only chooses where to click: every click is still verified, and the game walks its own
-- path to it (Exploration/Travel checks that path and the straight line to it as well).
local Entities = Ext.Require("Game/Entities.lua")
local Paths = Ext.Require("Game/Paths.lua")

local SafeRoute = {}

local CELL = 1.0             -- grid spacing, meters
local MAX_CLIMB = 1.5        -- height change allowed between neighbouring cells (steps: 1.3 m measured)
local CLEARANCE_CELLS = 1    -- cells kept between the way and a dangerous tile
-- Meters around the start and the rejoin point searched for a way: a near way first (cheap), then
-- a wider one (the gully on the Risen Road: 105 m round, 51 ms).
local BOX_MARGINS = { 20, 60 }
local MAX_EXPANDED = 40000   -- cells a search may take (a 200 x 200 m square)
local REJOIN_AFTER = 4.0     -- meters of safe route past the last dangerous point: back on the route
local MAX_DANGERS = 4        -- separate dangerous stretches gone round in one route
local BLOCKING = { WalkBlock = true, WalkBlockItem = true, SlopeBlock = true }

-- Ground cells of the grid, read once per search: cell(ix, iz, nearHeight) -> height or nil (not
-- walkable), and whether it is dangerous.
local function newGrid(danger)
    local cache = {}
    local grid = {}
    function grid.read(ix, iz)
        local key = ix * 100003 + iz
        local c = cache[key]
        if c then return c end
        c = {}
        local x, z = ix * CELL, iz * CELL
        local ok, heights = pcall(Ext.Level.GetHeightsAt, x, z)
        for _, h in ipairs(ok and heights or {}) do
            local okTile, t = pcall(Ext.Level.GetTileDebugInfo, { x, h, z })
            local blocked = false
            if okTile and t then
                for _, f in ipairs(t.Flags) do
                    if BLOCKING[tostring(f)] then blocked = true break end
                end
            end
            c[#c + 1] = { h = h, blocked = blocked, danger = danger({ x, h, z }) ~= nil }
        end
        cache[key] = c
        return c
    end
    -- The tile of column (ix, iz) nearest height h within MAX_CLIMB, or nil.
    function grid.at(ix, iz, h)
        local best
        for _, t in ipairs(grid.read(ix, iz)) do
            if math.abs(t.h - h) <= MAX_CLIMB and (not best or math.abs(t.h - h) < math.abs(best.h - h)) then best = t end
        end
        return best
    end
    -- Whether a dangerous tile lies within CLEARANCE_CELLS of the tile at (ix, iz) near height h
    -- (kept on the tile once known).
    function grid.nearDanger(ix, iz, h)
        local here = grid.at(ix, iz, h)
        if here and here.near ~= nil then return here.near end
        local near = false
        for dx = -CLEARANCE_CELLS, CLEARANCE_CELLS do
            for dz = -CLEARANCE_CELLS, CLEARANCE_CELLS do
                local t = grid.at(ix + dx, iz + dz, h)
                if t and t.danger then near = true end
            end
        end
        if here then here.near = near end
        return near
    end
    return grid
end

-- Binary heap of { f, ... } nodes.
local function push(heap, node)
    heap[#heap + 1] = node
    local i = #heap
    while i > 1 do
        local parent = i // 2
        if heap[parent].f <= heap[i].f then break end
        heap[parent], heap[i] = heap[i], heap[parent]
        i = parent
    end
end

local function pop(heap)
    local top = heap[1]
    local last = table.remove(heap)
    if #heap > 0 then
        heap[1] = last
        local i = 1
        while true do
            local l, r, m = i * 2, i * 2 + 1, i
            if heap[l] and heap[l].f < heap[m].f then m = l end
            if heap[r] and heap[r].f < heap[m].f then m = r end
            if m == i then break end
            heap[m], heap[i] = heap[i], heap[m]
            i = m
        end
    end
    return top
end

local NEIGHBOURS = {
    { 1, 0, 1 }, { -1, 0, 1 }, { 0, 1, 1 }, { 0, -1, 1 },
    { 1, 1, 1.4142 }, { 1, -1, 1.4142 }, { -1, 1, 1.4142 }, { -1, -1, 1.4142 },
}

-- A way on the grid from point a to point b that keeps CLEARANCE_CELLS off dangerous tiles:
-- { {x,y,z}, ... } (a's cell first, b's cell last) or nil. The start may itself be near danger
-- (the walker beside the fire): only the cells it moves into must be clear.
local function search(grid, a, b, margin)
    local sx, sz = math.floor(a[1] / CELL + 0.5), math.floor(a[3] / CELL + 0.5)
    local gx, gz = math.floor(b[1] / CELL + 0.5), math.floor(b[3] / CELL + 0.5)
    local minX = math.min(sx, gx) - margin / CELL
    local maxX = math.max(sx, gx) + margin / CELL
    local minZ = math.min(sz, gz) - margin / CELL
    local maxZ = math.max(sz, gz) + margin / CELL
    local goal = grid.at(gx, gz, b[2])
    if not goal or goal.blocked or goal.danger then return nil end
    -- Numeric node keys (cell and half-meter height band): string keys doubled the search time.
    local function key(ix, iz, h) return ((ix + 50000) * 100000 + (iz + 50000)) * 4096 + math.floor(h * 2 + 0.5) % 4096 end
    local function dist(ix, iz) return math.sqrt((ix - gx) ^ 2 + (iz - gz) ^ 2) * CELL end
    local start = { ix = sx, iz = sz, h = a[2], g = 0 }
    start.f = dist(sx, sz)
    local heap, best, came = { start }, { [key(sx, sz, a[2])] = 0 }, {}
    local expanded = 0
    while #heap > 0 do
        local n = pop(heap)
        local k = key(n.ix, n.iz, n.h)
        if n.g <= best[k] then
            if n.ix == gx and n.iz == gz and math.abs(n.h - goal.h) <= MAX_CLIMB then
                local out = {}
                local cur = n
                while cur do
                    table.insert(out, 1, { cur.ix * CELL, cur.h, cur.iz * CELL })
                    cur = came[key(cur.ix, cur.iz, cur.h)]
                end
                return out
            end
            expanded = expanded + 1
            if expanded > MAX_EXPANDED then return nil end
            for _, d in ipairs(NEIGHBOURS) do
                local ix, iz = n.ix + d[1], n.iz + d[2]
                if ix >= minX and ix <= maxX and iz >= minZ and iz <= maxZ then
                    local t = grid.at(ix, iz, n.h)
                    -- No cutting corners past a blocked or dangerous tile.
                    local diagonalOk = d[3] == 1 or (
                        (grid.at(n.ix + d[1], n.iz, n.h) or { blocked = true }).blocked == false
                        and (grid.at(n.ix, n.iz + d[2], n.h) or { blocked = true }).blocked == false)
                    -- Clearance is waived beside the start (the walker may stand at the edge)
                    -- and at the goal.
                    local waived = (math.abs(ix - sx) <= 2 and math.abs(iz - sz) <= 2) or (ix == gx and iz == gz)
                    if t and not t.blocked and not t.danger and diagonalOk and (waived or not grid.nearDanger(ix, iz, t.h)) then
                        local g = n.g + d[3] * CELL
                        local nk = key(ix, iz, t.h)
                        if not best[nk] or g < best[nk] then
                            best[nk] = g
                            came[nk] = n
                            push(heap, { ix = ix, iz = iz, h = t.h, g = g, f = g + dist(ix, iz) })
                        end
                    end
                end
            end
        end
    end
    return nil
end

-- Where the route is safe again after its dangerous point at index i: the first index at least
-- REJOIN_AFTER meters of safe route past the last dangerous point met; nil when the route ends
-- in danger.
local function rejoinIndex(points, i, danger)
    local lastDanger, since = i, 0
    for j = i + 1, #points do
        if danger(points[j]) then
            lastDanger, since = j, 0
        else
            since = since + Entities.Distance(points[j - 1], points[j])
            if since >= REJOIN_AFTER then return j end
        end
    end
    if lastDanger < #points then return #points end
    return nil
end

-- The last answer, reused for the same walker, target and position within REUSE_MS (a trip asks
-- twice per step: how far is left, and where to click).
local REUSE_MS = 2000
local last = nil

local function plan(uuid, target)
    local route = Paths.Find(uuid, target)
    if not route or not route.found then return route end
    local danger = Paths.DangerTest(uuid)
    if not danger then return route end
    local grid = nil
    local from = 2
    for _ = 1, MAX_DANGERS do
        local i = Paths.FirstDanger(uuid, route.points, from)
        if not i or (route.portals[1] and route.portals[1] <= i) then break end
        local j = rejoinIndex(route.points, i, danger)
        if not j then break end
        grid = grid or newGrid(danger)
        -- The first way round starts at the walker (planning from the route's last point before
        -- the danger walked Tav back up a dead-end gully toward it, 2026-09-24); later ones from
        -- a little before their danger, where the grid is still clear of it.
        local k = 1
        if from > 2 then
            k = i
            while k > from and grid.nearDanger(math.floor(route.points[k][1] / CELL + 0.5), math.floor(route.points[k][3] / CELL + 0.5), route.points[k][2]) do k = k - 1 end
        end
        local way
        for _, margin in ipairs(BOX_MARGINS) do
            way = search(grid, route.points[k], route.points[j], margin)
            if way then break end
        end
        if not way then break end
        local points = {}
        for n = 1, k - 1 do points[#points + 1] = route.points[n] end
        for _, p in ipairs(way) do points[#points + 1] = p end
        local shift = #points - j
        for n = j + 1, #route.points do points[#points + 1] = route.points[n] end
        local portals, portalInfo = {}, {}
        for _, p in ipairs(route.portals) do
            if p > j then
                portals[#portals + 1] = p + shift
                portalInfo[p + shift] = route.portalInfo[p]
            end
        end
        route = { found = true, points = points, flags = {}, portals = portals, portalInfo = portalInfo, aroundDanger = true }
        from = k + #way
    end
    return route
end

-- Paths.Find(uuid, target), with every dangerous stretch (before the first portal) replaced by a
-- way round it on the grid, when there is one. Same shape as Paths.Find's result, plus
-- aroundDanger = true when a way round was used; a stretch with no way round stays in (the
-- caller's danger checks stop before it and say why).
function SafeRoute.Find(uuid, target)
    local here = Entities.Position(uuid)
    local key = here and string.format("%s %.1f,%.1f,%.1f %.1f,%.1f,%.1f", uuid, target[1], target[2], target[3], here[1], here[2], here[3])
    local now = Ext.Utils.MonotonicTime()
    if key and last and last.key == key and now - last.time < REUSE_MS then return last.route end
    local route = plan(uuid, target)
    last = key and { key = key, time = now, route = route } or nil
    return route
end

return SafeRoute
