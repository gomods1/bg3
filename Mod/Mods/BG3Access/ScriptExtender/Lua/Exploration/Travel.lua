-- Getting the controlled character somewhere with the player's own clicks (gate.md 8.1, option 3;
-- CLAUDE.md: no magic movement). Follows the engine's route (Game/Paths): clicks the ground at the
-- farthest point of the route that is on screen (before any portal), waits until the character
-- stops, and repeats. The game walks the character with its own pathfinding; the party follows
-- as usual. Doors on the way are used like a player clicks them (announced). When too little of
-- the route is on screen (it runs under the HUD), the camera turns along it (Game/Camera, the
-- game's own Q/E keys). Every click is verified (Game/Activate). Ladders and passages on the
-- route are used the way a player does it: a click on them (the character walks there and climbs,
-- or goes through); a portal with no item to click still ends the trip with "needs a jump or a
-- climb".
local Activate = Ext.Require("Game/Activate.lua")
local Entities = Ext.Require("Game/Entities.lua")
local Paths = Ext.Require("Game/Paths.lua")
local SafeRoute = Ext.Require("Game/SafeRoute.lua")
local Camera = Ext.Require("Game/Camera.lua")
local Ui = Ext.Require("Game/Ui.lua")
local Combat = Ext.Require("Game/Combat.lua")
local Player = Ext.Require("Game/Player.lua")
local Clicks = Ext.Require("Exploration/TravelClicks.lua")
local Waits = Ext.Require("Exploration/TravelWaits.lua")
local Bridge = Ext.Require("Core/Bridge.lua")
local Speech = Ext.Require("Core/Speech.lua")
local Strings = Ext.Require("Core/Strings.lua")
local Timer = Ext.Require("Core/Timer.lua")

local Travel = {}

-- A surface type ("Fire") as spoken (for the callers' messages).
Travel.SurfaceName = Clicks.SurfaceName

local MAX_SEGMENTS = 40 -- long winding routes; real blockages end earlier (MAX_STALLS)
local MAX_OPENS = 3     -- objects on the way the character may use (doors) per trip
local MAX_LADDERS = 4   -- ladders climbed and passages used per trip
local LADDER_HEIGHTS = { 2.0, 3.0, 1.2, 4.0, 5.0 } -- aim points on a ladder, above its foot
local LADDER_DOWN_HEIGHTS = { 4.5, 4.0, 5.0, 3.5, 3.0 } -- from its top: the upper rungs first
local LADDER_TOP_ABOVE = 2.0 -- meters above a ladder's foot: the character is at its top
local MAX_STALLS = 2    -- clicks after which the character did not move: blocked
local POLL_MS = 250
local LOAD_WAIT_MS = 3000 -- at a target's known position, how long to wait for the client to load it
local LADDER_STOPPED_MS = 2500 -- the character stands still for a moment at the foot of a ladder (measured)
local MIN_VIEW_METERS = 4.0
-- Views tried (degrees from the route's heading) when no route point can be aimed at: along the
-- route, from either side, from the far side.
local TURN_OFFSETS = { 0, 90, -90, 180 } -- less route than this on screen: turn the camera along the route
-- Where the controlled character must be on screen (fractions); elsewhere the camera is centered.
local CENTER_BOX = { left = 0.25, right = 0.75, top = 0.25, bottom = 0.75 }

-- The shared loop. trip = { uuid?, target = fn() -> position or nil, finish = fn(cb) } where
-- finish is tried before every step and calls cb(done, ok, reason); done ends the trip.
local currentTrip = nil -- the trip in progress (Travel.Cancel ends it)
local searchStop = nil  -- ends Travel.GoToward's search for the nearest point (Travel.Cancel)
local NO_PROGRESS_METERS = 1.0
local MAX_NO_PROGRESS = 4

-- After a walk, the party members still far from the walker (a sighted player sees them lag or
-- stay behind): "Lejos del grupo: Gale a 40 metros". Checked a moment after arriving, when those
-- who follow have caught up.
local FOLLOW_CHECK_MS = 4000
local SCENE_CHECK_MS = 1000 -- a scene's widget can show after the clicks it spoiled already failed
local MAX_SCENE_WAITS = 3   -- remarks waited out per trip
local FAR_BEHIND_METERS = 20

local function sayWhoIsFar()
    local me = Entities.Controlled()
    local here = Entities.Position(me)
    if not here or currentTrip then return end
    local far = {}
    for _, uuid in ipairs(Player.PartyUuids()) do
        local p = uuid ~= me and Entities.Position(uuid)
        local d = p and Entities.Distance(p, here)
        if d and d > FAR_BEHIND_METERS then
            far[#far + 1] = Strings.Get("party_member_at", { name = Entities.Name(uuid) or "?", n = math.floor(d + 0.5) })
        end
    end
    if #far > 0 then Speech.Say(Strings.Get("party_far", { list = Strings.List(far) })) end
end

-- How far the character still has to walk: the engine's route length (a winding route can walk
-- meters without getting closer in a straight line: El Hueco -> Estanque sagrado, 2026-09-24);
-- the straight distance when there is no route.
local function metersLeft(from, target)
    local route = SafeRoute.Find(Entities.Controlled(), target)
    if route and route.found and #route.points > 1 then return Paths.Length(route.points) end
    return Entities.Distance(from, target) + math.abs(from[2] - target[2])
end

local function follow(trip, onDone)
    local segments, opened, stalls, lastStart = 0, 0, 0, nil
    -- The dangerous surface on the latest plan, if any: when the walk stops getting closer, that
    -- is why (a burning wreck too wide to go round, 2026-09-24).
    local lastDanger = nil
    local ladders = 0
    local attempt

    -- Camera turns made for the current segment (a turn does not count as a segment).
    local turnSegment, turns = nil, 0
    -- Set when the camera moved instead of the character: the next look is not a step that made
    -- no progress (four views used up the no-progress budget on the grove stairs, 2026-09-24).
    local cameraMoved = false
    local function turnsDone()
        return turnSegment == segments and turns or 0
    end
    -- Turns the camera to the next view in TURN_OFFSETS around the route's heading and looks
    -- again; false when every view was tried.
    local function turnCamera(info)
        if turnSegment ~= segments then turnSegment, turns = segments, 0 end
        if not info or turns >= #TURN_OFFSETS then return false end
        turns = turns + 1
        local a = math.rad(TURN_OFFSETS[turns])
        local dx, dz = info.heading[1], info.heading[2]
        segments = segments - 1
        lastStart = nil -- turning the camera does not move the character: not a stall
        cameraMoved = true
        Camera.TurnToward(dx * math.cos(a) - dz * math.sin(a), dx * math.sin(a) + dz * math.cos(a), attempt)
        return true
    end

    local centeredAt = nil
    local function step(lastReason)
        segments = segments + 1
        local me, target = Entities.Controlled(), trip.target()
        -- The camera left the character behind: center it (the game's key), once per segment.
        local here = Entities.Position(me)
        local fx, fy
        if here then fx, fy = Camera.Project(here) end
        if here and centeredAt ~= segments and (not fx or fx < CENTER_BOX.left or fx > CENTER_BOX.right
            or fy < CENTER_BOX.top or fy > CENTER_BOX.bottom) then
            centeredAt = segments
            segments = segments - 1
            lastStart = nil
            cameraMoved = true
            Camera.CenterOn(here, function() attempt() end)
            return
        end
        if segments > MAX_SEGMENTS or not target then
            onDone(false, target and "reason_no_path" or "reason_gone")
            return
        end
        local points, why, info, detail = Clicks.Candidates(me, target)
        lastDanger = info and info.danger
        -- Too little of the route on screen: turn the camera along it, as a sighted player
        -- would, then look again.
        if info and info.visibleMeters < MIN_VIEW_METERS and turnsDone() == 0 and turnCamera(info) then
            return
        end
        if not points and why == "reason_portal" and info and info.portal and info.portal.uuid and ladders < MAX_LADDERS then
            -- A ladder or a passage on the route: used like a player, with a click on it. A
            -- passage is an item that takes the character through (the "Entrada al cubil de
            -- huargos" into the goblin worg pens, 2026-09-24). A ladder is climbed from its foot
            -- or from its top (one over a wall in the sanctum is climbed up and then down the
            -- other side: from the top its lower rungs are behind the character, so the aim goes
            -- high first).
            ladders = ladders + 1
            lastStart = nil -- the walk to the ladder may be short: not a stall
            local uuid, ladder = info.portal.uuid, info.portal.ladder
            local here, foot = Entities.Position(me), Entities.Position(uuid)
            local down = ladder and here and foot and here[2] > foot[2] + LADDER_TOP_ABOVE
            local key = (not ladder and "using_passage") or (down and "climbing_down") or "climbing"
            Speech.Say(Strings.Get(key, { name = Entities.Name(uuid) or Strings.Get(ladder and "kind_ladder" or "kind_passage") }))
            Activate.WorldClick(uuid, function(used, err)
                if used then
                    Waits.UntilStopped(attempt, LADDER_STOPPED_MS)
                elseif not turnCamera(info) then
                    -- (A companion standing on the ladder's top hid it, in the sanctum: another
                    -- view is tried first.)
                    onDone(false, err)
                else
                    ladders = ladders - 1
                end
            end, ladder and (down and LADDER_DOWN_HEIGHTS or LADDER_HEIGHTS) or nil)
            return
        end
        if not points then
            Bridge.Log(string.format("travel: no point to click (%s, %.1f m of route on screen, %d camera turns)", tostring(why),
                info and info.visibleMeters or -1, turnsDone()))
            -- With a route but nothing left to click (the target is close), the last click's own
            -- failure says more; with no route at all (a dirt mound 84 m away on another level of
            -- the Risen Road, 2026-09-24), "no way there" does.
            onDone(false, (why == "reason_no_path" and info and lastReason) or why, detail)
            return
        end
        Clicks.TakeRefused()
        Clicks.ClickFirst(points, function(clicked, reason, blocker)
            local refused = Clicks.TakeRefused()
            if clicked then
                Waits.UntilStopped(attempt)
            elseif reason == "reason_no_cursor" and refused then
                -- Every click was refused for a dangerous surface near its way: a step aside,
                -- else the surface is why.
                local danger = refused
                local aside, asideRoute = Clicks.Detour(me, target, danger.point)
                local asidePoints = aside and Clicks.ClickablePoints(me, asideRoute, #asideRoute.points)
                if asidePoints and #asidePoints > 0 then
                    Bridge.Log(string.format("travel: %s near the way, stepping aside to %.1f,%.1f", tostring(danger.surface), aside[1], aside[3]))
                    Clicks.ClickFirst(asidePoints, function(stepped)
                        if stepped then
                            Waits.UntilStopped(attempt)
                        else
                            onDone(false, "reason_surface", { surface = Clicks.SurfaceName(danger.surface) })
                        end
                    end, nil, asideRoute.points)
                else
                    onDone(false, "reason_surface", { surface = Clicks.SurfaceName(danger.surface) })
                end
            elseif blocker and trip.uuid and blocker.uuid == trip.uuid then
                -- The target itself is under the cursor on the way (Warryn's body lying in the
                -- rubble at the character's feet, 2026-09-24: aimed clicks on it failed): that
                -- click is the interaction.
                Activate.ObjectClickAt(blocker.point, blocker.uuid, function(used, err)
                    if used then onDone(true) else onDone(false, err) end
                end)
            elseif blocker and blocker.uuid ~= trip.uuid and opened < MAX_OPENS then
                -- Something stands on the way (a closed door, measured on the nautiloid): use it,
                -- as a player clicks a door to open it, then go on.
                opened = opened + 1
                Speech.Say(Strings.Get("using_on_the_way", { name = Entities.Name(blocker.uuid) or "?" }))
                Activate.ObjectClickAt(blocker.point, blocker.uuid, function(used, err)
                    if not used then
                        onDone(false, err)
                    elseif Entities.IsDoor(blocker.uuid) then
                        -- A door takes a moment to open; looking again too soon found it still
                        -- closed and the second click shut it (the nautiloid's first Esfínter,
                        -- 2026-09-24): wait until the game reports it open.
                        Waits.WhenDoorOpen(blocker.uuid, function() Waits.UntilStopped(attempt) end)
                    else
                        Waits.UntilStopped(attempt)
                    end
                end)
            elseif (reason == "reason_no_cursor" or (reason == "reason_on_object" and not blocker))
                and turnCamera(info) then
                -- None of the points could be aimed at (the ground there is hidden from this
                -- camera angle, measured near the nautiloid's pods; covered by the character's
                -- own body, on the way to the grove gate; a rock between the camera and the
                -- character, in the grove): the camera turned to the next view; look again.
                return
            else
                onDone(false, reason)
            end
        end, trip.uuid, info and info.route)
    end

    local inCombatAtStart = Combat.Current() ~= nil
    -- Who walks: a click can still land on a companion who steps under the cursor and select them
    -- (Gale, twice on the road west of the Risen Road waypoint, 2026-09-24; Activate.GroundClick
    -- keeps a margin around companions): then the walker is selected again, as a portrait click
    -- would, before the next step.
    local walker = Entities.Controlled()
    local myTrip = {}
    currentTrip = myTrip
    local bestLeft, noProgress = nil, 0
    local finish = onDone
    local sceneWaits = 0
    local function finishTrip(ok, reason, detail)
        if currentTrip == myTrip then currentTrip = nil end
        if ok then Timer.After(FOLLOW_CHECK_MS, sayWhoIsFar) end
        finish(ok, reason, detail)
    end
    onDone = function(ok, reason, detail)
        if ok or reason == "reason_cancelled" or reason == "reason_interrupted" then
            finishTrip(ok, reason, detail)
            return
        end
        -- A scene that starts on the way takes the camera before its widget shows (Jeorna on the
        -- grove stairs, 2026-09-24: the next clicks were "off screen"), sometimes only after
        -- the failed clicks (the ogres' ambient "¿Gallina?", 230 ms later, Blighted Village
        -- 2026-09-25). A remark that closes by itself lets the walk go on; any other scene ends
        -- it and speaks for itself.
        Timer.After(SCENE_CHECK_MS, function()
            if not Ui.FrontBlockingWidget() then
                finishTrip(ok, reason, detail)
            elseif sceneWaits >= MAX_SCENE_WAITS then
                finishTrip(false, "reason_interrupted")
            else
                sceneWaits = sceneWaits + 1
                Waits.AfterRemark(attempt, function() finishTrip(false, "reason_interrupted") end)
            end
        end)
    end
    attempt = function()
        if currentTrip ~= myTrip then
            onDone(false, "reason_cancelled")
            return
        end
        if walker and Entities.Controlled() ~= walker then
            Bridge.Log("travel: the selection moved to " .. tostring(Entities.Name(Entities.Controlled())) .. "; selecting the walker again")
            Player.Select(walker)
        end
        -- Clicks that keep the character moving without getting closer (stairs between two
        -- levels in the grove: the clicks landed on the other level, 2026-09-24): give up.
        local target, here0 = trip.target(), Entities.Position(Entities.Controlled())
        local looked = cameraMoved
        cameraMoved = false
        if target and here0 and not looked then
            local left = metersLeft(here0, target)
            if bestLeft and left > bestLeft - NO_PROGRESS_METERS then
                noProgress = noProgress + 1
                if noProgress >= MAX_NO_PROGRESS then
                    if lastDanger then
                        onDone(false, "reason_surface", { surface = lastDanger })
                    else
                        onDone(false, "reason_no_progress")
                    end
                    return
                end
            else
                noProgress = 0
            end
            if not bestLeft or left < bestLeft then bestLeft = left end
        end
        -- The game opened a screen (a dialogue started on the way, a loot window...): the trip is
        -- over; that screen speaks for itself. A companion's remark on the way (Lae'zel on the
        -- nautiloid, 2026-09-24: "Nos aproximamos al puente") is a dialogue too, but it closes by
        -- itself without answers: then the walk goes on.
        if Ui.FrontBlockingWidget() then
            Waits.AfterRemark(attempt, function() onDone(false, "reason_interrupted") end)
            return
        end
        -- A fight started on the way (measured on the beach: the trip kept clicking in combat and
        -- spent the turn's movement): stop; the combat announcements take over.
        if not inCombatAtStart and Combat.Current() then
            onDone(false, "reason_combat")
            return
        end
        -- A click that did not move the character means something blocks the way.
        local here = Entities.Position(Entities.Controlled())
        if lastStart and here and Entities.Distance(here, lastStart) < Clicks.MIN_STEP_METERS / 2 then
            stalls = stalls + 1
            if stalls >= MAX_STALLS then
                onDone(false, "reason_blocked")
                return
            end
        end
        lastStart = here
        trip.finish(function(done, ok, reason)
            if done then onDone(ok, reason) else step(reason) end
        end)
    end

    attempt()
end

-- A step away from a target the character stands on (Warryn's body lay under Tav: every aim point
-- hit Tav). Ground behind the character, as the camera sees it, is covered by the character's body
-- (measured: 2.5 m past the body picked Tav), so the step goes toward the camera first, then to
-- either side.
local STEP_BACK_NEAR = 1.8
local TURN_NEAR = 8.0 -- meters: a target this close that cannot be clicked is first looked at
local STEP_BACK_METERS = 2.5

local function stepBackPoints(me)
    local right, forward = Camera.GroundAxes()
    if not right then return {} end
    local out = {}
    for _, d in ipairs({ { -forward[1], -forward[2] }, { right[1], right[2] }, { -right[1], -right[2] } }) do
        out[#out + 1] = { me[1] + d[1] * STEP_BACK_METERS, me[2], me[3] + d[2] * STEP_BACK_METERS }
    end
    return out
end

-- Tries each point with a verified ground click; onDone(ok).
local function stepToFirst(points, onDone, i)
    i = i or 1
    if not points[i] then
        onDone(false)
        return
    end
    Activate.GroundClick(points[i], function(ok)
        if ok then onDone(true) else stepToFirst(points, onDone, i + 1) end
    end)
end

-- A step away when the character stands on or right by target uuid (its body hides it from the
-- cursor): 2.5 m toward the camera, else to either side. onDone(stepped) once the character
-- stopped. Also for the lists' context menus (a dirt mound 1 m ahead of Tav, 2026-09-24).
function Travel.StepAwayFrom(uuid, onDone)
    local me, target = Entities.Position(Entities.Controlled()), Entities.Position(uuid)
    if not (me and target) or Entities.Distance(me, target) >= STEP_BACK_NEAR then
        onDone(false)
        return
    end
    stepToFirst(stepBackPoints(me), function(stepped)
        if stepped then Waits.UntilStopped(function() onDone(true) end) else onDone(false) end
    end)
end

-- true while a trip is under way.
function Travel.IsActive()
    return currentTrip ~= nil or searchStop ~= nil
end

-- Ends the trip in progress at its next step (its onDone gets "reason_cancelled").
function Travel.Cancel()
    currentTrip = nil
    if searchStop then
        searchStop()
        searchStop = nil
    end
end

-- Trips end with onDone(ok, reasonKey, detail); detail fills the reason's placeholders
-- (reason_door_closed: { door }). Travel.FailureText says it.

-- Reasons that speak for themselves: a scene or a screen opened, a fight started, the player
-- stopped the walk.
local SILENT_REASONS = { reason_interrupted = true, reason_combat = true, reason_cancelled = true }

-- What to say when a trip to label did not get there; nil when the reason is silent.
function Travel.FailureText(label, reason, detail)
    if SILENT_REASONS[reason] then return nil end
    return Strings.Get("could_not_activate", { label = label, reason = Strings.Get(reason or "reason_no_path", detail) })
end

-- Walks to entity uuid and interacts with it like a click. onDone(ok, reasonKey, detail).
-- knownPosition: where the entity is when the client has not loaded it yet (a map marker: Arron
-- 55 m away, inside the grove's upper level, 2026-09-24); the walk heads there until it loads.
function Travel.Interact(uuid, onDone, knownPosition)
    local steppedBack, turned = false, false
    local function click(cb)
        Activate.WorldClick(uuid, function(ok, reason)
            local me, target = Entities.Position(Entities.Controlled()), Entities.Position(uuid)
            if not ok and not turned and me and target and Entities.Distance(me, target) < TURN_NEAR
                and (reason == "reason_offscreen" or reason == "reason_no_cursor") then
                -- A target this close is hidden by the view, not by distance: turn the camera
                -- toward it first (Gale 2 m behind Tav: walking toward a companion who follows
                -- took 100 s of steps and camera turns, 2026-09-24).
                turned = true
                Camera.TurnToward(target[1] - me[1], target[3] - me[3], function() click(cb) end)
                return
            end
            if not ok and not steppedBack and me and target and Entities.Distance(me, target) < STEP_BACK_NEAR then
                steppedBack = true
                stepToFirst(stepBackPoints(me), function(stepped)
                    if stepped then Waits.UntilStopped(function() cb(false) end) else cb(false, false, reason) end
                end)
                return
            end
            -- Off screen or hidden behind something: walk closer first.
            cb(ok or reason == "reason_gone", ok, reason)
        end)
    end
    -- At the known position the client loads the target a moment later (Arron: gone on arrival,
    -- loaded 1.3 m away when looked again): wait for it before giving up.
    local function whenLoaded(waitedMs, cb)
        if Entities.Position(uuid) then click(cb) return end
        if waitedMs >= LOAD_WAIT_MS then cb(true, false, "reason_gone") return end
        Timer.After(POLL_MS, function() whenLoaded(waitedMs + POLL_MS, cb) end)
    end
    follow({
        uuid = uuid,
        target = function() return Entities.Position(uuid) or knownPosition end,
        finish = function(cb)
            if Entities.Position(uuid) then click(cb) return end
            local here = knownPosition and Entities.Position(Entities.Controlled())
            if here and Entities.Distance(here, knownPosition) > Clicks.ARRIVE_METERS then cb(false) return end
            whenLoaded(0, cb)
        end,
    }, onDone)
end

-- Walks to a point (e.g. a quest marker; snapped to walkable ground). onDone(ok, reasonKey, detail).
-- arrived(): optional, true once the trip is over before the point itself (inside a named place).
-- A walk that stalls within NEAR_STOP_METERS of the point ends there, arrived near it (a mark at
-- the foot of stairs: every click on it picked the step above, where Tav already stood, 3.5 m
-- away, Blighted Village 2026-09-25): onDone(true, nil, { short = meters left }).
local NEAR_STOP_METERS = 5
function Travel.GoTo(point, onDone, arrived)
    point = Paths.Snap(point)
    follow({
        target = function() return point end,
        finish = function(cb)
            local here = Entities.Position(Entities.Controlled())
            cb((here ~= nil and Entities.Distance(here, point) <= Clicks.ARRIVE_METERS) or (arrived ~= nil and arrived()), true, nil)
        end,
    }, function(ok, reason, detail)
        local here = Entities.Position(Entities.Controlled())
        local left = here and Entities.Distance(here, point)
        if not ok and (reason == "reason_blocked" or reason == "reason_no_progress") and left and left <= NEAR_STOP_METERS then
            onDone(true, nil, { short = math.max(1, math.floor(left + 0.5)) })
            return
        end
        onDone(ok, reason, detail)
    end)
end

-- Walks as close to a point as the ways allow (a quest marker behind a gate the story keeps
-- closed: the goblin camp's, 2026-09-24), as a sighted player heads for a marker seen on the map.
-- With a route there, or a closed door on the way (said as the reason), this is Travel.GoTo.
-- Otherwise the walk goes to the reachable point nearest it (Paths.NearestReachable), said
-- first; onDone(true, nil, { short = meters left to the point }) on arriving there.
function Travel.GoToward(point, onDone)
    local me = Entities.Controlled()
    local route = Paths.Find(me, point)
    if (route and route.found) or Paths.ClosedDoorOnWay(me, point) then
        Travel.GoTo(point, onDone)
        return
    end
    Speech.Say(Strings.Get("searching_nearest"))
    local finished = false
    local stop = Paths.NearestReachable(me, point, function(near)
        finished = true
        searchStop = nil
        if not near then onDone(false, "reason_no_path") return end
        local short = math.floor(Entities.Distance(near, point) + 0.5)
        Speech.Say(Strings.Get("walking_nearest", { n = short }))
        Travel.GoTo(near, function(ok, reason, detail)
            if ok then onDone(true, nil, { short = short }) else onDone(ok, reason, detail) end
        end)
    end)
    if not finished then
        -- Still searching (it can also end at once): Travel.Cancel stops it.
        searchStop = function()
            stop()
            onDone(false, "reason_cancelled")
        end
    end
end

return Travel
