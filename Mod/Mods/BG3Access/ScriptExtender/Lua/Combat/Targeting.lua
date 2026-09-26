-- Targeting mode (template_rpg 17.1, gate.md 9): after an action is armed (Combat/Actions), Up/Down
-- cycle the possible targets, enemies first then others, nearest first. Each move puts the cursor
-- over the target (verified hover, no click) and reads the game's own preview (Game/Preview): hit
-- chance, damage range, the walk it needs first, attack of opportunity. Enter confirms through the
-- game's own targeting command (Game/Combat.TargetArmedAction), no mouse: the character walks and
-- acts by the game's rules. (Confirm clicks proved unreliable after keyboard use.) Escape cancels
-- with the game's key. Preview values are never announced as events. The character itself is a
-- target too (healing, a potion thrown...), after the enemies; the preview says when it is not
-- allowed. For area spells (Fireball on an imp) the list also says who else the area catches
-- (Combat/Area, an estimate from the stats).
-- Throw has two steps: first the thing to throw (only what the character can pick up: Game/
-- Throwing), then where it goes (creatures, things, a place on the ground).
local Combat = Ext.Require("Game/Combat.lua")
local Throwing = Ext.Require("Game/Throwing.lua")
local Items = Ext.Require("Game/Items.lua")
local Hud = Ext.Require("Screens/Hud.lua")
local Entities = Ext.Require("Game/Entities.lua")
local Activate = Ext.Require("Game/Activate.lua")
local Hotbar = Ext.Require("Game/Hotbar.lua")
local Interactables = Ext.Require("Game/Interactables.lua")
local CombatLog = Ext.Require("Game/CombatLog.lua")
local Preview = Ext.Require("Game/Preview.lua")
local Camera = Ext.Require("Game/Camera.lua")
local Words = Ext.Require("Combat/Words.lua")
local Area = Ext.Require("Combat/Area.lua")
local Spells = Ext.Require("Game/Spells.lua")
local Speech = Ext.Require("Core/Speech.lua")
local Strings = Ext.Require("Core/Strings.lua")
local ListScreen = Ext.Require("Screens/ListScreen.lua")
local Controls = Ext.Require("Screens/Controls.lua")
local Timer = Ext.Require("Core/Timer.lua")

local L = Strings.Get

local Targeting = ListScreen.Extend()

local WORLD_TARGET_RADIUS = 25 -- meters: characters and objects to attack beyond the combatants
local WORLD_TARGET_MAX_DY = 8
local COMMAND_CHECK_MS = 1200 -- after the portrait command, the action starts or stays armed
local CAMERA_SETTLE_MS = 600 -- the camera glides to its new centre
local PREVIEW_SETTLE_MS = 350 -- the preview follows the hover on later frames

-- actionName: spoken title; onClose: called when targeting ends (confirmed or cancelled).
-- choosePlace: optional; when given, the list ends with "a place on the ground", which calls it
-- (for actions that take a creature or a place, e.g. Fire Bolt: Combat/Place).
-- opts: { spell = spell id } (for the area estimate).
function Targeting.New(actionName, onClose, choosePlace, opts)
    local self = setmetatable(ListScreen.New("(targeting)", L("screen_targeting", { action = actionName or "?" })), Targeting)
    self.onClose, self.choosePlace = onClose, choosePlace
    self.spell = opts and opts.spell
    self.spellInfo = Spells.Info(self.spell)
    local me = Entities.Controlled()
    self.me = me
    local targets = {}
    for _, c in ipairs(Combat.Combatants()) do
        -- Downed party members stay targets (Help stabilises them, a scroll revives them).
        if c.uuid and ((c.hp or 0) > 0 or c.relation == "Player") then
            local p, mine = Entities.Position(c.uuid), Entities.Position(me)
            c.distance = (p and mine) and Entities.Distance(p, mine) or math.huge
            targets[#targets + 1] = c
        end
    end
    -- What else a sighted player could click with the action armed: out of combat the
    -- characters around, and objects that can be attacked (the base under Lae'zel's cage). These
    -- have no combatant view model: they are confirmed with a verified click on them.
    local mine = Entities.Position(me)
    local listed = {}
    for _, t in ipairs(targets) do listed[t.uuid] = true end
    local function addWorld(o)
        if listed[o.uuid] or o.uuid == me then return end
        listed[o.uuid] = true
        local hp, maxHp = Entities.Health(o.uuid)
        targets[#targets + 1] = {
            uuid = o.uuid, name = o.name, hp = hp, maxHp = maxHp, world = true,
            distance = mine and Entities.Distance(o.position, mine) or math.huge,
        }
    end
    if mine then
        if not Combat.Current() then
            for _, o in ipairs(Interactables.Near(mine, WORLD_TARGET_RADIUS, WORLD_TARGET_MAX_DY)) do
                if o.category == "character" and not Entities.IsDead(o.uuid) then addWorld(o) end
            end
        end
        for _, o in ipairs(Interactables.Attackable(mine, WORLD_TARGET_RADIUS, WORLD_TARGET_MAX_DY)) do addWorld(o) end
    end
    table.sort(targets, function(a, b)
        local ea, eb = a.relation == "Enemy", b.relation == "Enemy"
        if ea ~= eb then return ea end
        return a.distance < b.distance
    end)
    self.targets = targets
    self.allTargets = targets
    local armed = Hotbar.ArmedAction()
    if armed and armed.targeting == "Throw" and not armed.object then self:StartPicking() end
    return self
end

-- A throw's first step: only what the character can pick up is listed, once the server said
-- which things are movable (the list stays empty, and unannounced, until then).
function Targeting:StartPicking()
    self.picking, self.pickReady = true, false
    local items = {}
    for _, t in ipairs(self.allTargets) do
        if not Entities.IsCharacter(t.uuid) then items[#items + 1] = t.uuid end
    end
    Items.Fetch(items, function()
        local keep = {}
        for _, t in ipairs(self.allTargets) do
            if t.uuid ~= self.me and Throwing.CanThrow(self.me, t.uuid, Entities.IsCharacter(t.uuid)) then keep[#keep + 1] = t end
        end
        self.targets, self.pickReady = keep, true
    end)
end

function Targeting:Build()
    if self.picking and not self.pickReady then return {} end
    local out = {}
    for _, t in ipairs(self.targets) do
        out[#out + 1] = Controls.Item({
            kind = "button",
            describe = function()
                return Strings.List({ Words.Combatant(t), t.uuid == self.me and L("target_self") })
            end,
        })
    end
    local targets = Preview.Targets()
    if targets and targets.chosen > 0 then
        out[#out + 1] = Controls.Button({
            label = L("targets_cast_now", { n = targets.chosen, max = targets.max }),
            activate = function(done)
                local ok = Preview.CastNow()
                done(ok, "reason_unavailable")
                if ok then self:Close() end
            end,
        })
    end
    if self.choosePlace and not self.picking then
        out[#out + 1] = Controls.Item({
            kind = "button",
            describe = function() return L("target_place_item") end,
            activate = function()
                self.handedOver = true -- its own place cursor takes over the same action
                self.choosePlace()
            end,
        })
    end
    return out
end

-- Focus = hover: speak the target at once, then the game's preview for it.
function Targeting:Speak(control)
    local t = self.targets[self.index]
    Speech.Say(control.Describe(), { interrupt = true })
    if not t then return end
    local index = self.index
    local centred, turned, told = false, false, false
    local function onHover(ok, reason)
        if self.index ~= index then return end -- the player moved on
        -- The camera moves below can take 10-15 s in all (an archer on a ledge in the worg pens:
        -- the preview came 16 s after the name, 2026-09-25): say that the aim goes on.
        if not ok and not told and (reason == "reason_offscreen" or reason == "reason_no_cursor") then
            told = true
            Speech.Say(L("target_aiming", { name = t.name or "?" }))
        end
        if not ok and reason == "reason_offscreen" and not centred and Combat.CenterCameraOn(t.uuid) then
            -- Bring the target to the screen centre (the game's camera command), as a sighted
            -- player pans the camera to it.
            centred = true
            Timer.After(CAMERA_SETTLE_MS, function()
                if self.index == index then Activate.Hover(t.uuid, onHover) end
            end)
            return
        end
        if not ok and (reason == "reason_offscreen" or reason == "reason_no_cursor") and not turned then
            -- Turn the camera toward the target (the game's Q/E): off screen, or covered from
            -- this side (a slab of pork behind Tav on a goblin camp table, Throw, 2026-09-24).
            turned = true
            local me, p = Entities.Position(Entities.Controlled()), Entities.Position(t.uuid)
            if me and p then
                Camera.TurnToward(p[1] - me[1], p[3] - me[3], function()
                    if self.index == index then Activate.Hover(t.uuid, onHover) end
                end)
                return
            end
        end
        if not ok and (reason == "reason_offscreen" or reason == "reason_no_cursor") and not self.tactical then
            -- Last: the game's tactical camera, from above (the dark worg pens: every target
            -- refused the cursor and the turn swung into a pillar; from above they could be
            -- aimed at, 2026-09-25). Put back when targeting ends.
            Camera.SetTactical(true, function(changed)
                self.tactical = changed and "mine" or "was"
                if self.index ~= index then return end
                if changed then Activate.Hover(t.uuid, onHover) else onHover(false, reason) end
            end)
            return
        end
        if not ok then
            Speech.Say(L("could_not_activate", { label = t.name or "?", reason = L(reason) }))
            return
        end
        Timer.After(PREVIEW_SETTLE_MS, function()
            if self.index == index and Activate.IsHovering(t.uuid) then
                Speech.Say(Strings.List({ Words.Preview(Preview.Read(), nil, self.spellInfo), self:AreaWords(t.uuid) }))
            end
        end)
    end
    Activate.Hover(t.uuid, onHover)
end

-- Who else an area spell aimed at this target would catch, or nil (no area).
function Targeting:AreaWords(uuid)
    local p = Entities.Position(uuid)
    local caught = p and Area.Catches(self.spell, self.me, p)
    if not caught then return nil end
    return Words.AreaCatches(caught, uuid)
end

function Targeting:Activate(aimed)
    if self.index > #self.targets then return ListScreen.Activate(self) end -- the place item
    local t = self.targets[self.index]
    if not t then
        Speech.Say(L("nothing_selected"), { interrupt = true })
        return
    end
    local function failed(reasonKey)
        -- The game's own reason when it has one: Scorching Ray on an archer answered "the game
        -- did not react" three times while the preview said "¡Un obstáculo bloquea el paso!"
        -- (the hover check had lapsed, so the command was tried; worg pens, 2026-09-25).
        local p = Preview.Read()
        if not p.canExecute and #p.messages > 0 then
            Speech.Say(Words.Preview(p, nil, self.spellInfo), { interrupt = true })
            return
        end
        Speech.Say(L("could_not_activate", { label = t.name or "?", reason = L(reasonKey or "reason_unavailable") }), { interrupt = true })
    end
    if Activate.IsHovering(t.uuid) then
        -- The game's preview for this very target: refuse what the game would refuse, with its
        -- reason ("¡Un obstáculo bloquea el paso!").
        local p = Preview.Read()
        if not p.canExecute then
            Speech.Say(Words.Preview(p, nil, self.spellInfo), { interrupt = true })
            return
        end
        -- The portrait command is exact, but it dropped a ranged spell that needed a walk first
        -- (Fire Bolt on Gimblebock 23 m away, 2026-09-24): then a click on the verified target,
        -- as a sighted player does, makes the game walk into range. Never a click on oneself: the
        -- click lands ~220 ms after the hover check, and on 2026-09-24 a click meant for
        -- Shadowheart herself (Healing Word) walked her away from an enemy (attack of
        -- opportunity, downed).
        -- Several-target actions too: the portrait command added Magic Missile's first dart but
        -- not a second one on the same goblin (2026-09-24).
        if (p.moveCost or t.world or Preview.Targets()) and t.uuid ~= Entities.Controlled() then
            self:ClickTarget(t, failed)
            return
        end
    end
    if not aimed and not Activate.IsHovering(t.uuid) then
        -- Aim at it first: the portrait command acted on whoever the cursor was over (Sacred
        -- Flame meant for Azak hit Roah, 2026-09-25). Only when it cannot be aimed at is the
        -- command used.
        local index = self.index
        Activate.Hover(t.uuid, function(ok)
            if self.index ~= index then return end
            self:Activate(true)
        end)
        return
    end
    if t.world then
        failed("reason_no_cursor") -- no view model: only a click on it can confirm
        return
    end
    if aimed and not Activate.IsHovering(t.uuid) and not self.parkedForCommand then
        -- The aim failed where the cursor may rest on someone else: off the world first.
        self.parkedForCommand = true
        Activate.Park(function() self:Activate(true) end)
        return
    end
    self.parkedForCommand = false
    local before = self:Before()
    if not Combat.TargetArmedAction(t.uuid) then
        failed("reason_unavailable")
        return
    end
    -- The command can be accepted and still do nothing (Sacred Flame on Warryn up on a ledge:
    -- "No hay ningún objetivo", 2026-09-24): the action is then still armed and the log silent.
    Timer.After(COMMAND_CHECK_MS, function()
        self:AfterConfirm(self:ConfirmResult(before), t, failed)
    end)
end

-- After a confirm (command or click), on a later frame: "done" (the action left the armed state or
-- the log moved), "more" (a several-target action took this target and waits for more), "picked"
-- (a throw took its object and now waits for where to throw it), or "none".
function Targeting:ConfirmResult(before)
    local targets = Preview.Targets()
    if targets and before.targets and targets.chosen > before.targets.chosen then return "more" end
    if not (Hotbar.Armed() and CombatLog.Count() == before.log) then return "done" end
    local armed = Hotbar.ArmedAction()
    if armed and armed.object and not before.object then return "picked" end
    return "none"
end

function Targeting:Before()
    self.confirming = true
    local armed = Hotbar.ArmedAction()
    return { log = CombatLog.Count(), targets = Preview.Targets(), object = armed and armed.object }
end

-- A throw took its object: the same list now chooses where it goes ("Lanzar: Tenedor").
function Targeting:ObjectPicked()
    self.confirming = false
    local armed = Hotbar.ArmedAction()
    local object = armed and armed.object
    self.title = L("screen_targeting", { action = L("label_value", { label = armed and armed.name or "?", value = object and object.name or "?" }) })
    self.picking, self.targets = false, self.allTargets
    self.index = 0
    self:Open()
end

-- What a confirm led to (ConfirmResult); on "none" failed(reasonKey) says so, retry() may try
-- once more first.
function Targeting:AfterConfirm(result, t, failed, retry)
    if result ~= "done" then self.confirming = false end
    if result == "done" then
        self:Close()
    elseif result == "more" then
        self:MoreTargets(t)
    elseif result == "picked" then
        self:ObjectPicked()
    elseif retry then
        retry()
    else
        failed("reason_no_effect")
    end
end

-- A several-target action took target t: say how many are chosen and stay for the next one.
function Targeting:MoreTargets(t)
    self.confirming = false
    local targets = Preview.Targets()
    self:Refresh()
    Speech.Say(L("targets_chosen", { name = t.name or "?", n = targets and targets.chosen or 0, max = targets and targets.max or 0 }), { interrupt = true })
end

-- Confirms on target t with a verified click, checked like the command: the action must leave
-- the armed state or the log must move. One click was lost once (Fire Bolt on the base under
-- Lae'zel's cage: the cursor on it at 100%, nothing happened; the same click again worked), so
-- a lost click is repeated once before failing.
function Targeting:ClickTarget(t, failed, retried)
    local before = self:Before()
    Activate.ClickHovered(t.uuid, function(ok, reason)
        if not ok then
            failed(reason)
            return
        end
        Timer.After(COMMAND_CHECK_MS, function()
            local retry = not retried and Activate.IsHovering(t.uuid) and function() self:ClickTarget(t, failed, true) end
            self:AfterConfirm(self:ConfirmResult(before), t, failed, retry or nil)
        end)
    end)
end

function Targeting:Close()
    if self.tactical == "mine" then Camera.SetTactical(false, function() end) end
    if self.onClose then self.onClose() end
end

-- A game screen took the place of this list before a confirm (a quick save): the HUD opens
-- targeting again for the action if it is still armed afterwards. After a confirm the action is
-- under way (Gale's Fire Bolt: a screen came up during the cast, and targeting reopened for the
-- attack the game armed next, 2026-09-25): nothing to reopen.
function Targeting:OnReplaced()
    if not self.confirming and not self.handedOver then Hud.FollowAgain() end
end

function Targeting:Help()
    return { L("help_targeting") }
end

function Targeting:OnKey(combo)
    if combo == "ESCAPE" and #self.levels == 0 then
        -- The game's ActionCancel; with nothing armed Escape would open the game menu.
        if Hotbar.Armed() then Activate.CancelArmed() end
        Speech.Say(L("cancelled"), { interrupt = true })
        self:Close()
        return true
    end
    if combo == "SPACE" then return false end -- the game's end turn stays the game's
    return ListScreen.OnKey(self, combo)
end

return Targeting
