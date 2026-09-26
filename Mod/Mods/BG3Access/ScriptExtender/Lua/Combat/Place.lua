-- Place cursor (template_rpg 17.1, gate.md 9): for an armed action that takes a place on the ground
-- (Jump, area spells, a Fire Bolt at the floor). A point on the ground starts at the character;
-- arrows move it relative to the camera (up = away from the camera), 1 m, or 5 m with Shift; Home
-- brings it back. Every move puts the game's cursor there (a sighted helper sees the same place),
-- snaps the point to the ground the game picks there, and speaks the offset, what is under the
-- cursor and the game's own preview (possible or not, movement used, hit chance...). Enter clicks
-- there only when the game's preview says the action can be done; the game then does it by its own
-- rules (verified with Jump: "Tav ha usado Saltar."). Escape cancels with the game's key.
-- For area actions it also says who the area would catch there (Combat/Area, from the stats).
local Activate = Ext.Require("Game/Activate.lua")
local Hotbar = Ext.Require("Game/Hotbar.lua")
local Camera = Ext.Require("Game/Camera.lua")
local Entities = Ext.Require("Game/Entities.lua")
local Picking = Ext.Require("Game/Picking.lua")
local Preview = Ext.Require("Game/Preview.lua")
local Ui = Ext.Require("Game/Ui.lua")
local Bridge = Ext.Require("Core/Bridge.lua")
local Speech = Ext.Require("Core/Speech.lua")
local Strings = Ext.Require("Core/Strings.lua")
local Words = Ext.Require("Combat/Words.lua")
local Area = Ext.Require("Combat/Area.lua")
local Spells = Ext.Require("Game/Spells.lua")
local Combat = Ext.Require("Game/Combat.lua")
local Travel = Ext.Require("Exploration/Travel.lua")
local CombatLog = Ext.Require("Game/CombatLog.lua")
local Timer = Ext.Require("Core/Timer.lua")
local Hud = Ext.Require("Screens/Hud.lua")
local Paths = Ext.Require("Game/Paths.lua")
local TravelClicks = Ext.Require("Exploration/TravelClicks.lua")
local SurfaceName = TravelClicks.SurfaceName

local L = Strings.Get

local Place = {}
Place.__index = Place

local STEP = 1
local BIG_STEP = 5
local PREVIEW_SETTLE_MS = 350 -- the preview follows the cursor on later frames
local SNAP_RADIUS = 1.5       -- picked ground this close to the point (meters, on the ground plane) is the point
local SNAP_HEIGHT = 0.3       -- re-aim when the ground is this much above or below the point
local CLICK_CHECK_MS = 1200   -- an armed action has left the armed state (or the log moved) by then
local MOVES = {
    UP = { 0, 1 }, DOWN = { 0, -1 }, RIGHT = { 1, 0 }, LEFT = { -1, 0 },
}

-- actionName: spoken title; onClose: called when the cursor ends (confirmed or cancelled);
-- opts: { spell = spell id (for the area estimate), title = spoken title instead of "Place for
-- <action>", start = {x, y, z} (where the cursor starts; default the character), move = true
-- (a walk: Enter refuses while a character or item is under the cursor, since the click would act
-- on it: measured, a corpse under the cursor previewed an attack), alternatives = { points }
-- (other start points, tried in order when the start cannot be aimed at) }.
-- With no action armed the same cursor is a move: the game previews the walk (verified in combat:
-- 3.9 m previewed, the click walked Lae'zel there and spent exactly that).
function Place.New(actionName, onClose, opts)
    opts = opts or {}
    local self = setmetatable({ action = actionName or "?", onClose = onClose, seq = 0, spell = opts.spell, title = opts.title, move = opts.move, alternatives = opts.alternatives }, Place)
    self.me = Entities.Controlled()
    local p = opts.start or Entities.Position(self.me)
    self.point = p and { p[1], p[2], p[3] } or nil
    return self
end

local function round(v) return math.floor(v + 0.5) end

local function flatDistance(a, b)
    local dx, dz = a[1] - b[1], a[3] - b[3]
    return math.sqrt(dx * dx + dz * dz)
end

-- "2 ahead, 1 right, 1 up, 2.2 meters away" from the character, in the camera's frame.
function Place:Offset()
    local me = Entities.Position(self.me)
    local right, forward = Camera.GroundAxes()
    if not (me and right) then return "" end
    local dx, dy, dz = self.point[1] - me[1], self.point[2] - me[2], self.point[3] - me[3]
    local ahead, side = round(dx * forward[1] + dz * forward[2]), round(dx * right[1] + dz * right[2])
    local parts = {}
    if ahead > 0 then parts[#parts + 1] = L("place_ahead", { n = ahead }) end
    if ahead < 0 then parts[#parts + 1] = L("place_back", { n = -ahead }) end
    if side > 0 then parts[#parts + 1] = L("place_right", { n = side }) end
    if side < 0 then parts[#parts + 1] = L("place_left", { n = -side }) end
    if #parts == 0 then return L("place_here") end
    if dy >= 1 then parts[#parts + 1] = L("place_up", { n = round(dy) }) end
    if dy <= -1 then parts[#parts + 1] = L("place_down", { n = round(-dy) }) end
    parts[#parts + 1] = L("place_distance", { n = Entities.Distance(me, self.point) })
    return Strings.List(parts)
end

-- What the game shows at the cursor: the object under it and the preview. The character's own body
-- often covers the ground just ahead of it (the camera looks down from behind): the cursor is then
-- on the character, not on the ground (measured: Fire Bolt "not possible" 1 m ahead; a move 3 m
-- ahead previewed nothing), so it is said.
function Place:AtCursor()
    local uuid = Picking.HoveredObjectUuid()
    local preview = Preview.Read()
    local me = Entities.Position(self.me)
    local covered = uuid == self.me and me and flatDistance(me, self.point) > 0.5
    if self.move then
        -- A walk: only the walk's own preview (a stale attack preview stays in UIData, measured).
        preview = { canExecute = preview.canExecute, moveCost = preview.moveCost, moveLeft = preview.moveLeft,
            surface = preview.surface, opportunityAttack = preview.opportunityAttack, advantages = 0, disadvantages = 0 }
    end
    local caught = Area.Catches(self.spell, self.me, self.point)
    -- A walk in combat follows the game's own path, through fire or electrified water if that is
    -- the way (Shadowheart, Gale and Tav each walked through electrified water to Gut's passage,
    -- 2026-09-25): the first dangerous surface on the route is said.
    local crosses = nil
    if self.move and Combat.Current() then
        local route = Paths.Find(self.me, self.point)
        local surface = nil
        if route and route.found then
            local _
            _, surface = Paths.FirstDanger(self.me, route.points, 2)
        end
        if surface then crosses = L("move_crosses", { surface = SurfaceName(surface) }) end
    end
    return Strings.List({
        covered and L("place_on_self"),
        uuid and uuid ~= self.me and L("place_on", { name = Entities.Name(uuid) or "?" }),
        preview.canExecute and L("place_possible"), -- said, so a valid place is never silence
        Words.Preview(preview, "movement_cost", Spells.Info(self.spell)),
        caught and Words.AreaCatches(caught),
        crosses,
    })
end

-- Puts the game's cursor on the point and lets the preview settle; onDone(ok, reasonKey) on the
-- same move only (a newer move cancels the older one). The camera turns toward a point off screen,
-- once per move.
function Place:Aim(onDone)
    self.seq = self.seq + 1
    local seq = self.seq
    local turned, refined = false, false
    local function go()
        local fx, fy = Activate.SafeProjection(self.point)
        if not fx then
            local me = Entities.Position(self.me)
            if turned or not me then
                onDone(false, "reason_offscreen")
                return
            end
            turned = true
            Camera.TurnToward(self.point[1] - me[1], self.point[3] - me[3], function()
                if self.seq == seq then go() end
            end)
            return
        end
        Bridge.Send(string.format("mouse move %.4f %.4f", fx, fy))
        Ext.Timer.WaitForRealtime(PREVIEW_SETTLE_MS, function()
            if self.seq ~= seq then return end
            if Ui.WidgetUnderPointer() then
                onDone(false, "reason_no_cursor")
                return
            end
            local g = Picking.Ground()
            if not g or flatDistance(g, self.point) > SNAP_RADIUS then
                onDone(true, "place_hidden")
                return
            end
            -- Follow the terrain: aim again at the ground's height (a projection at the wrong height
            -- lands elsewhere along the view ray).
            if not refined and math.abs(g[2] - self.point[2]) > SNAP_HEIGHT then
                refined = true
                self.point[2] = g[2]
                go()
                return
            end
            onDone(true)
        end)
    end
    go()
end

function Place:Speak()
    Speech.Say(self:Offset(), { interrupt = true })
    self:Aim(function(ok, reason)
        if not ok then
            Speech.Say(L(reason))
            return
        end
        local text = self:AtCursor()
        if reason then text = Strings.List({ L(reason), text }) end
        Speech.Say(text)
    end)
end

function Place:Open()
    if not self.point then
        Speech.Say(L("not_available_here"), { interrupt = true })
        self:Close()
        return
    end
    Speech.Say(self.title or L("screen_place", { action = self.action }), { interrupt = true })
    local alternatives = self.alternatives or {}
    local function try(i)
        self:Aim(function(ok, reason)
            -- The start point is under the HUD, hidden, or (for a walk) covered by a character or
            -- item: try the next one offered.
            local covered = ok and self.move and Picking.HoveredObjectUuid()
            if (not ok or covered) and alternatives[i] then
                local a = alternatives[i]
                self.point = { a[1], a[2], a[3] }
                try(i + 1)
                return
            end
            Speech.Say(ok and self:AtCursor() or L(reason))
        end)
    end
    try(1)
end

function Place:Move(right, ahead)
    local r, f = Camera.GroundAxes()
    if not r then return end
    self.point[1] = self.point[1] + right * r[1] + ahead * f[1]
    self.point[3] = self.point[3] + right * r[2] + ahead * f[2]
    self:Speak()
end

function Place:Home()
    local p = Entities.Position(self.me)
    if p then self.point = { p[1], p[2], p[3] } end
    self:Speak()
end

-- Enter: aim again and read the preview on that very frame; click only when the game can do it.
-- Outside combat a move is a walk there (Exploration/Travel: the route followed with verified
-- clicks): one click at the cursor landed on whatever ground the camera showed there, and a move
-- 8 m ahead walked 1.7 m (the worg pens, 2026-09-24). In combat the one previewed click keeps the
-- movement spent exactly as previewed.
function Place:Confirm()
    if self.move and not Combat.Current() then
        local point, action = { self.point[1], self.point[2], self.point[3] }, self.action
        self:Close()
        Speech.Say(L("walking"), { interrupt = true })
        Travel.GoTo(point, function(ok, reason, detail)
            local text = ok and L("arrived") or Travel.FailureText(action, reason, detail)
            if text then Speech.Say(text) end
        end)
        return
    end
    self:Aim(function(ok, reason)
        if not ok then
            Speech.Say(L("could_not_activate", { label = self.action, reason = L(reason) }), { interrupt = true })
            return
        end
        if not Preview.Read().canExecute then
            Speech.Say(L("target_invalid"), { interrupt = true })
            return
        end
        local on = self.move and Picking.HoveredObjectUuid()
        if on then
            Speech.Say(L("move_on_object", { name = Entities.Name(on) or "?" }), { interrupt = true })
            return
        end
        self:Click()
    end)
end

-- Clicks at the aimed point. A click can be lost (the fork's throw, 2026-09-25: the first click
-- did nothing, a second one threw it), so for an armed action it is checked as Targeting's
-- confirm is (the action left the armed state or the log moved) and aimed and clicked once more.
function Place:Click(retried)
    self.clicked = true
    local log = CombatLog.Count()
    Bridge.Send("mouse click left")
    if self.move then
        self:Close()
        return
    end
    local seq = self.seq
    Timer.After(CLICK_CHECK_MS, function()
        if self.seq ~= seq then return end -- the player moved the cursor or left
        if not Hotbar.Armed() or CombatLog.Count() ~= log then
            self:Close()
        elseif retried then
            Speech.Say(L("could_not_activate", { label = self.action, reason = L("reason_no_effect") }), { interrupt = true })
        else
            self:Aim(function(ok) if ok then self:Click(true) end end)
        end
    end)
end

-- A game screen took the place of the cursor before a click: the HUD opens targeting again if
-- still armed (after a click the action is under way).
function Place:OnReplaced()
    if not self.clicked then Hud.FollowAgain() end
end

function Place:Close()
    self.seq = self.seq + 1 -- drops pending aims
    if self.onClose then self.onClose() end
end

function Place:ReadAll()
    self:Speak()
end

function Place:Help()
    return { L("help_place") }
end

function Place:OnKey(combo)
    local shift = combo:match("^SHIFT%+(.+)$")
    local dir = MOVES[shift or combo]
    if dir then
        local step = shift and BIG_STEP or STEP
        self:Move(dir[1] * step, dir[2] * step)
        return true
    end
    if combo == "HOME" then self:Home() return true end
    if combo == "RETURN" or combo == "KP_ENTER" then self:Confirm() return true end
    if combo == "ESCAPE" then
        -- The game's ActionCancel; with nothing armed Escape would open the game menu.
        if Hotbar.Armed() then Activate.CancelArmed() end
        Speech.Say(L("cancelled"), { interrupt = true })
        self:Close()
        return true
    end
    return false -- Space (end turn) and the game's other keys stay the game's
end

return Place
