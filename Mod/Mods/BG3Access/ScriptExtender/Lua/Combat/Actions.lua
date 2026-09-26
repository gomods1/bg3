-- Actions list (mod menu, a mod screen): the controlled character's hotbar (Game/Hotbar) as a list:
-- name, cost, count for items, unavailable. Enter arms the action like a click on its slot, then by
-- the game's targeting type (for items: the type of the spell the item casts, Game/Spells):
--   Target                 targeting mode (Combat/Targeting): creatures, the character included;
--   Shout                  confirmed at once on the character itself through the game's targeting
--                          command (verified with Rage: bonus action and a Rage charge spent);
--   Projectile, Throw      targeting mode with "a place on the ground" as the last entry;
--   any other type (Zone, Jump's Projectile_Jump, a scroll's Teleportation...)  the place cursor
--                          (Combat/Place);
--   potions                the game uses them at once (verified: the healing potion was drunk,
--                          "Tav ha usado Poción de curación."; the combat log narrates it);
--   other items without a spell  the place cursor if the game armed them (untested).
-- Levelled spells: Left/Right choose the spell slot level to cast with (upcasting: the game's
-- variant of the spell for that level, Game/Hotbar.UseAt), with the slots left at that level.
local Hotbar = Ext.Require("Game/Hotbar.lua")
local Combat = Ext.Require("Game/Combat.lua")
local Entities = Ext.Require("Game/Entities.lua")
local Speech = Ext.Require("Core/Speech.lua")
local Strings = Ext.Require("Core/Strings.lua")
local ListScreen = Ext.Require("Screens/ListScreen.lua")
local Controls = Ext.Require("Screens/Controls.lua")
local Targeting = Ext.Require("Combat/Targeting.lua")
local Place = Ext.Require("Combat/Place.lua")
local Hud = Ext.Require("Screens/Hud.lua")

local L = Strings.Get

local Actions = ListScreen.Extend()

local COSTS = { Action = "cost_action", BonusAction = "cost_bonus", Reaction = "cost_reaction" }
local HOW = { Target = "creature", Shout = "self", Projectile = "creatureOrPlace", Throw = "creatureOrPlace" }
-- Actions whose type says otherwise but that only make sense on a place.
local PLACE_ONLY = { Projectile_Jump = true }
local ARM_SETTLE_MS = 150 -- UseSlotCommand is deferred: confirm on a later frame
local USE_SETTLE_MS = 400 -- an item used at once: the game has cleared or set the armed slot by then

-- open(handler): shows another mod screen in this one's place (the router's OpenModScreen).
function Actions.New(open, onClose)
    local self = setmetatable(ListScreen.New("(actions)", L("screen_actions")), Actions)
    self.open, self.onClose = open, onClose
    return self
end

-- The slot level chosen for a (Left/Right), else its own.
function Actions:LevelOf(a)
    return self.levels[a.bar .. ":" .. a.slot] or a.spellLevel
end

-- "level 2, 2 slots left" for a levelled spell at level.
local function levelWords(level)
    local slots = Hotbar.SpellSlots()[level]
    return Strings.List({ L("cast_level", { n = level }), slots and L("spell_slots_left", { n = slots.value }) })
end

function Actions:Describe(a)
    local parts = { a.name or a.id or "?" }
    if a.count and a.count > 1 then parts[#parts + 1] = L("item_count_only", { n = a.count }) end
    if a.levels then
        parts[#parts + 1] = levelWords(self:LevelOf(a))
    elseif (a.spellLevel or 0) > 0 then
        parts[#parts + 1] = L("spell_level", { n = a.spellLevel })
    end
    if COSTS[a.cost or ""] then parts[#parts + 1] = L(COSTS[a.cost]) end
    if not Hotbar.CanUse(a.bar, a.slot) then parts[#parts + 1] = L("unavailable") end
    return Strings.List(parts)
end

-- Left/Right on a levelled spell: the next slot level it can be cast with (a variant the game
-- marks unusable is said so).
function Actions:ChangeLevel(a, delta)
    local at = 1
    for i, v in ipairs(a.levels) do
        if v.level == self:LevelOf(a) then at = i end
    end
    local v = a.levels[math.max(1, math.min(#a.levels, at + delta))]
    self.levels[a.bar .. ":" .. a.slot] = v.level
    Speech.Say(Strings.List({ levelWords(v.level), not v.canUse and L("unavailable") }), { interrupt = true })
end

function Actions:Build()
    self.levels = self.levels or {}
    local out = {}
    for _, a in ipairs(Hotbar.Actions()) do
        out[#out + 1] = Controls.Item({
            kind = "button",
            describe = function() return self:Describe(a) end,
            activate = function() self:Use(a) end,
            change = a.levels and function(delta) self:ChangeLevel(a, delta) end or nil,
        })
    end
    return out
end

local function refuse(name)
    Speech.Say(L("could_not_activate", { label = name or "?", reason = L("reason_unavailable") }), { interrupt = true })
end

-- Opens the mod's targeting for an armed action by the game's targeting type (see the top):
-- open(screen) shows it, onClose ends it; name is the title, id the spell. confirmSelf: a Shout is
-- confirmed on the character at once (armed from the list); otherwise it gets the creature list
-- with the character in it (armed by the game's own key: the player confirms).
function Actions.OpenTargeting(open, onClose, name, id, targeting, confirmSelf)
    Hud.Followed()
    local function place() open(Place.New(name, onClose, { spell = id })) end
    local how = PLACE_ONLY[id or ""] and "place" or HOW[targeting or ""] or "place"
    if how == "self" and not confirmSelf then how = "creature" end
    if how == "creature" then
        open(Targeting.New(name, onClose, nil, { spell = id }))
    elseif how == "creatureOrPlace" then
        open(Targeting.New(name, onClose, place, { spell = id }))
    elseif how == "self" then
        if onClose then onClose() end
        Ext.Timer.WaitForRealtime(ARM_SETTLE_MS, function()
            if not Combat.TargetArmedAction(Entities.Controlled()) then refuse(name) end
        end)
    else
        place()
    end
end

-- Targeting for an action the game armed by itself (Screens/Hud: its number keys, an item's
-- "Lanzar"); a throw with its object chosen is titled with it ("Lanzar: Tenedor").
function Actions.FollowArmed(open, onClose, a)
    local name = a.object and L("label_value", { label = a.name or "?", value = a.object.name or "?" }) or a.name
    Actions.OpenTargeting(open, onClose, name, a.id, a.targeting, false)
end

function Actions:Use(a)
    -- A levelled spell at another slot level is the game's variant for that level (its own id:
    -- Projectile_MagicMissile_2 throws four darts).
    local level, spell = self:LevelOf(a), a.id
    local variant = nil
    for _, v in ipairs(a.levels or {}) do
        if v.level == level and level ~= a.spellLevel then variant = v end
    end
    if variant then spell = variant.id or spell end
    local armed = variant and (variant.canUse and Hotbar.UseAt(a.bar, a.slot, level)) or (not variant and Hotbar.CanUse(a.bar, a.slot) and Hotbar.Use(a.bar, a.slot))
    if not armed then
        refuse(a.name)
        return
    end
    Hud.Followed() -- this list follows it (potions and items too)
    local function place() self.open(Place.New(a.name, self.onClose, { spell = spell })) end
    if a.useType == "Potion" then
        if self.onClose then self.onClose() end -- drunk at once; the combat log says so
        return
    end
    if a.item and not a.targeting then
        Ext.Timer.WaitForRealtime(USE_SETTLE_MS, function()
            if Hotbar.Armed() then place() elseif self.onClose then self.onClose() end
        end)
        return
    end
    Actions.OpenTargeting(self.open, self.onClose, a.name, spell, a.targeting, true)
end

function Actions:Help()
    local lines = ListScreen.Help(self)
    lines[#lines + 1] = L("help_actions_levels")
    return lines
end

function Actions:OnKey(combo)
    if combo == "SPACE" then return false end
    return ListScreen.OnKey(self, combo)
end

return Actions
