-- Base for the mod's in-game lists of places and things (Nearby, Markers): a mod screen over the HUD
-- (Screens/Router.OpenModScreen). Entries are plain data:
--   { name, uuid? (an entity: Enter walks there and uses it), position? (a point: Enter walks
--     there), describeExtra = fn(entry) -> string? (state words), afterUse = fn(entry)? }
-- Sorted nearest first; each line says name, distance, direction (Exploration/Direction), then the
-- extra words. Escape closes. Enter travels there (Exploration/Travel); in combat, where every
-- meter counts, it opens the Move cursor (Combat/Place) at the farthest point of the route that
-- this turn's movement reaches, and the player confirms there; an object within 3 m is used with
-- a click instead (never a character: that click would attack).
local Travel = Ext.Require("Exploration/Travel.lua")
local Entities = Ext.Require("Game/Entities.lua")
local Direction = Ext.Require("Exploration/Direction.lua")
local Paths = Ext.Require("Game/Paths.lua")
local Combat = Ext.Require("Game/Combat.lua")
local Characters = Ext.Require("Game/Characters.lua")
local Player = Ext.Require("Game/Player.lua")
local Place = Ext.Require("Combat/Place.lua")
local Activate = Ext.Require("Game/Activate.lua")
local Camera = Ext.Require("Game/Camera.lua")
local Items = Ext.Require("Game/Items.lua")
local Signposts = Ext.Require("Game/Signposts.lua")
local ItemWords = Ext.Require("Screens/ItemWords.lua")
local ContextMenuList = Ext.Require("Screens/ContextMenuList.lua")
local ContextMenu = Ext.Require("Game/ContextMenu.lua")
local Preview = Ext.Require("Game/Preview.lua")
local Speech = Ext.Require("Core/Speech.lua")
local Strings = Ext.Require("Core/Strings.lua")
local ListScreen = Ext.Require("Screens/ListScreen.lua")
local Controls = Ext.Require("Screens/Controls.lua")
local Ui = Ext.Require("Game/Ui.lua")
local Timer = Ext.Require("Core/Timer.lua")

local L = Strings.Get

-- After using a passage: how long until the party must have been moved, and how far.
local PASSAGE_CHECK_MS = 6000
local TALK_CHECK_MS = 4000
local CONFIRM_MS = 8000
local PASSAGE_MOVED_METERS = 8

local PlaceList = ListScreen.Extend()

local function entryPosition(e)
    return (e.uuid and Entities.Position(e.uuid)) or e.position
end

local function distanceTo(e)
    local me = Entities.Position(Entities.Controlled())
    local p = entryPosition(e)
    if not (me and p) then return nil end
    return Entities.Distance(me, p)
end

-- title: spoken name of the list; entries: see above; onClose: called when the list closes;
-- open: shows another mod screen in the list's place (the router's OpenModScreen; needed for the
-- Move cursor in combat).
function PlaceList.New(id, title, entries, onClose, open)
    local self = setmetatable(ListScreen.New(id, title), PlaceList)
    self.open = open
    -- Nearest first, the dead after the living (after the gate fight a dozen bodies came before
    -- anyone to talk to, 2026-09-24).
    for _, e in ipairs(entries) do
        e.sortDistance = distanceTo(e) or math.huge
        e.sortDead = e.uuid ~= nil and Entities.IsCharacter(e.uuid) and Entities.IsDead(e.uuid)
    end
    table.sort(entries, function(a, b)
        -- Entries may rank themselves first (map markers: objectives before the rest).
        if (a.rank or 0) ~= (b.rank or 0) then return (a.rank or 0) < (b.rank or 0) end
        if a.sortDead ~= b.sortDead then return not a.sortDead end
        return a.sortDistance < b.sortDistance
    end)
    self.entries = entries
    self.onClose = onClose
    -- What the game's tooltip says of the items listed, for Ctrl+D (asked of the server now, so
    -- it is there when the player asks).
    local items = {}
    for _, e in ipairs(entries) do
        if e.uuid and not e.details and not Entities.IsCharacter(e.uuid) then items[#items + 1] = e.uuid end
    end
    if #items > 0 then Items.Fetch(items) end
    return self
end

function PlaceList.Describe(e)
    local parts = { e.name or "?" }
    local d = distanceTo(e)
    if d then parts[#parts + 1] = L("meters", { n = math.floor(d + 0.5) }) end
    parts[#parts + 1] = Direction.Words(Entities.Position(Entities.Controlled()), entryPosition(e))
    local extra = e.describeExtra and e.describeExtra(e)
    if extra and extra ~= "" then parts[#parts + 1] = extra end
    return Strings.List(parts)
end

local MOVE_MARGIN = 0.3 -- meters kept from the end of the movement (rounding)

-- The route points to p that movement meters reach (before any portal), nearest first.
local function reachable(p, movement)
    local route = Paths.Find(Entities.Controlled(), p)
    if not (route and route.found and #route.points > 1) then return nil end
    local limit = route.portals[1] and route.portals[1] - 1 or #route.points
    local walked, out = 0, {}
    for i = 2, limit do
        walked = walked + Entities.Distance(route.points[i - 1], route.points[i])
        if walked > movement - MOVE_MARGIN then break end
        out[#out + 1] = route.points[i]
    end
    return out
end

local ALTERNATIVE_SPACING = 1.5 -- meters between the start points offered to the cursor
local MAX_ALTERNATIVES = 6

-- The points on screen (the place cursor aims with the mouse), farthest first, spaced out.
local function onScreenFarthestFirst(points)
    local out = {}
    for i = #points, 1, -1 do
        local p = points[i]
        local last = out[#out]
        if Activate.SafeProjection(p) and (not last or Entities.Distance(p, last) >= ALTERNATIVE_SPACING) then
            out[#out + 1] = p
            if #out > MAX_ALTERNATIVES then break end
        end
    end
    return out
end

function PlaceList:MoveToward(e)
    local me = Characters.Snapshot(Player.SelectedCharacter())
    local movement = me and me.movement or 0
    local p = entryPosition(e)
    local points = p and movement > 1 and reachable(p, movement)
    if not (points and #points > 0) then
        Speech.Say(L("could_not_activate", { label = e.name or "?", reason = L(movement > 1 and "reason_no_path" or "reason_no_movement") }), { interrupt = true })
        return
    end
    local function open()
        local starts = onScreenFarthestFirst(points)
        if #starts == 0 then
            Speech.Say(L("could_not_activate", { label = e.name or "?", reason = L("reason_offscreen") }), { interrupt = true })
            return
        end
        local start = table.remove(starts, 1)
        self.open(Place.New(L("action_move"), self.onClose,
            { title = L("screen_move_toward", { name = e.name or "?" }), start = start, alternatives = starts, move = true }))
    end
    local last, here = points[#points], Entities.Position(Entities.Controlled())
    if Activate.SafeProjection(last) or not here then
        open()
    else
        -- Turn the camera along the way first (the game's Q/E), as a sighted player would.
        Camera.TurnToward(last[1] - here[1], last[3] - here[3], open)
    end
end

local USE_REACH_METERS = 3 -- in combat, objects this close are used with a click (the game walks the rest)
local USE_TRY_METERS = 18 -- farther, a click is tried when the game's preview says the walk fits

function PlaceList:Use(e)
    -- A trap is never walked onto (a click on it walks there; disarming is the game's own action).
    if e.category == "trap" then
        Speech.Say(L("trap_keep_away", { name = e.name or "?" }), { interrupt = true })
        return
    end
    if Combat.Current() and self.open then
        local d = distanceTo(e)
        if e.uuid and not Entities.IsCharacter(e.uuid) and d and d <= USE_TRY_METERS then
            -- An object within reach: the player's click on it (never on a character: that
            -- click attacks).
            -- The walk to it can leave an enemy's reach: the game's hover preview warns of the
            -- attack of opportunity (Tav walking to his dropped greataxe took one from Zurk with
            -- no warning, 2026-09-25); a second Enter within CONFIRM_MS goes anyway.
            local function fail(reason)
                Speech.Say(L("could_not_activate", { label = e.name or "?", reason = L(reason or "reason_no_cursor") }), { interrupt = true })
            end
            Activate.Hover(e.uuid, function(ok, reason)
                local preview = ok and Preview.Read()
                -- Farther than arm's reach, the game's hover preview says whether the walk to it
                -- fits this turn (Gut's passage 4 m away needed a separate Move and a second
                -- Enter, 2026-09-25): a click then walks and uses it; else the Move cursor.
                if (not ok or not preview.canExecute) and d > USE_REACH_METERS then
                    self:MoveToward(e)
                    return
                end
                if not ok then fail(reason) return end
                local now = Ext.Timer.MonotonicTime()
                local confirmed = self.confirmUse == e.uuid and now < (self.confirmUseUntil or 0)
                if preview.opportunityAttack and not confirmed then
                    self.confirmUse, self.confirmUseUntil = e.uuid, now + CONFIRM_MS
                    Speech.Say(L("use_provokes", { name = e.name or "?" }), { interrupt = true })
                    return
                end
                self.confirmUse = nil
                Speech.Say(L("using", { name = e.name or "?" }), { interrupt = true })
                Activate.ClickHovered(e.uuid, function(clicked, why)
                    if clicked then self:Close("") else fail(why) end
                end)
            end)
            return
        end
        self:MoveToward(e)
        return
    end
    Speech.Say(L("going_to", { name = e.name or "?" }), { interrupt = true })
    local retried = false
    local done
    -- A passage (an item portal: the Shattered Sanctum's "Puertas pesadas de roble", cave mouths)
    -- takes the party elsewhere: a use click that moved nobody was lost or refused (the first
    -- click on the Sanctum's doors after a 60 m walk did nothing; the worg pens' entrance answered
    -- "No puedes llegar", 2026-09-25): the thing's menu "Use" is tried once.
    local function checkPassage()
        local from = Entities.Position(Entities.Controlled())
        Timer.After(PASSAGE_CHECK_MS, function()
            local now = Entities.Position(Entities.Controlled())
            if not (from and now) or Entities.Distance(from, now) > PASSAGE_MOVED_METERS or Ui.FrontBlockingWidget() then return end
            if retried then return end
            retried = true
            -- The game's own "Use" from the thing's menu finds ways the plain click does not.
            ContextMenu.UseFirst(e.uuid, function(used, reason, entry)
                if used then
                    Speech.Say(L("using", { name = entry or e.name or "?" }), { interrupt = true })
                else
                    Speech.Say(L("could_not_activate", { label = e.name or "?", reason = L(reason or "reason_no_effect") }), { interrupt = true })
                end
            end)
        end)
    end
    done = function(ok, reasonKey, detail)
        if not ok then
            local text = Travel.FailureText(e.name or "?", reasonKey, detail)
            if text then Speech.Say(text, { interrupt = true }) end
            return
        end
        self:Close("")
        if detail and detail.short then
            Speech.Say(L("arrived_near", { name = e.name or "?", n = detail.short }))
        elseif not e.uuid then
            -- A point (a mark, a map marker's spot): no use follows to speak for the arrival.
            Speech.Say(L("arrived_at", { name = e.name or "?" }))
        end
        if e.afterUse then e.afterUse(e) end
        if e.uuid and Entities.IsPassage(e.uuid) and not Entities.IsLadder(e.uuid) then checkPassage() end
        if e.uuid and Entities.IsCharacter(e.uuid) and not Entities.IsDead(e.uuid) and not retried then
            -- A talk click can be lost after a walk (Auntie Ethel in the grove: walked to, clicked,
            -- nothing opened; the same click again started the conversation, 2026-09-25): when no
            -- screen of the game's comes up, the click is made once more.
            Timer.After(TALK_CHECK_MS, function()
                if Ui.FrontBlockingWidget() or Combat.Current() or retried then return end
                retried = true
                Travel.Interact(e.uuid, function() end, e.position)
            end)
        end
    end
    -- A point with no character or object (a map marker) may lie where no way goes yet: the walk
    -- then ends as close as the ways allow.
    if e.uuid and Signposts.Is(e.uuid) then Signposts.WatchReading(e.uuid) end
    if e.uuid then Travel.Interact(e.uuid, done, e.position) else Travel.GoToward(e.position, done) end
end

-- Where things' context menus open (a right click on a thing in the world).
local WORLD_MENU = "WorldContextMenu"
local ACTIONS_NEAR = 6 -- meters: farther, the character walks there before the right click
local STEP_AWAY_NEAR = 1.8 -- meters: closer, the character's body can hide the thing

-- The game's context menu of entry e (a verified right click on it, as a player does: pick up,
-- dig, throw, examine...; verified 2026-09-24 on a shovel: "Recoger, Recoger y añadir a la
-- mercancía, Empezar a cavar (Tav), Lanzar, Examinar") as a sub-list. A thing farther than
-- ACTIONS_NEAR is walked to first.
function PlaceList:EntryActions(e)
    local stepped, turned = false, false
    local function open()
        Activate.ContextClick(e.uuid, function(ok, reason, fx, fy)
            local me, p = Entities.Position(Entities.Controlled()), entryPosition(e)
            local near = me and p and Entities.Distance(me, p) < STEP_AWAY_NEAR
            if not ok and near and not stepped then
                -- Under the character's feet (a dirt mound 1 m ahead of Tav, the Blighted
                -- Village): a step away first, once.
                stepped = true
                Travel.StepAwayFrom(e.uuid, open)
                return
            end
            if not ok and me and p and not turned then
                -- Hidden from this view: look at it first, once.
                turned = true
                Camera.TurnToward(p[1] - me[1], p[3] - me[3], open)
                return
            end
            if not ok then
                Speech.Say(L("could_not_activate", { label = e.name or "?", reason = L(reason or "reason_no_cursor") }), { interrupt = true })
                return
            end
            ContextMenuList.Open(self, WORLD_MENU, L("item_actions", { name = e.name or "?" }), { fx, fy }, e.name or "?",
                function() self:Refresh() end)
        end)
    end
    local d = distanceTo(e)
    if d and d > ACTIONS_NEAR then
        Speech.Say(L("going_to", { name = e.name or "?" }), { interrupt = true })
        Travel.GoTo(entryPosition(e), function(ok, reasonKey, detail)
            if ok then
                open()
            else
                local text = Travel.FailureText(e.name or "?", reasonKey, detail)
                if text then Speech.Say(text, { interrupt = true }) end
            end
        end)
    else
        open()
    end
end

-- The mod menu's commands for this list: the context menu of the thing in focus.
function PlaceList:Commands()
    local c = self:Current()
    local e = c and c.entry
    if not (e and e.uuid) then return {} end
    return { { label = L("item_actions", { name = e.name or "?" }), run = function() self:EntryActions(e) end } }
end

function PlaceList:Build()
    local out = {}
    for _, e in ipairs(self.entries) do
        local control = Controls.Item({
            kind = "button",
            describe = function() return PlaceList.Describe(e) end,
            activate = function() self:Use(e) end,
            details = function()
                if e.details then return e.details(e) end
                return e.uuid and ItemWords.WorldDetails(Items.WorldInfo(e.uuid))
            end,
        })
        control.entry = e
        out[#out + 1] = control
    end
    return out
end

-- message: nil = "Closed", "" = silent.
function PlaceList:Close(message)
    if message ~= "" then Speech.Say(message or L("closed"), { interrupt = true }) end
    if self.onClose then self.onClose() end
end

function PlaceList:OnKey(combo)
    if combo == "ESCAPE" and #self.levels == 0 then
        self:Close()
        return true
    end
    return ListScreen.OnKey(self, combo)
end

return PlaceList
