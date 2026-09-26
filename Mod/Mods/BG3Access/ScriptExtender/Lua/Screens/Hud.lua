-- The in-game state with only the HUD in front (router name "(hud)"): the game's own keys work
-- (camera, hotbar, F-keys...). The mod claims only Space in combat, to confirm ending the turn
-- while the controlled character still has an action or a bonus action (template_rpg 17.1):
-- the first press says what is left, a second press within CONFIRM_MS ends the turn with the
-- game's own key. Config combat.confirmEndTurn = false turns this off.
-- An action the game arms by itself (its number keys, X, an item's "Lanzar") is followed by the
-- mod's targeting (Hud.OnArmed, wired by Setup/Commands to Combat/Actions.FollowArmed).
local Combat = Ext.Require("Game/Combat.lua")
local Hotbar = Ext.Require("Game/Hotbar.lua")
local Activate = Ext.Require("Game/Activate.lua")
local Characters = Ext.Require("Game/Characters.lua")
local Player = Ext.Require("Game/Player.lua")
local Words = Ext.Require("Combat/Words.lua")
local Config = Ext.Require("Core/Config.lua")
local Speech = Ext.Require("Core/Speech.lua")
local Strings = Ext.Require("Core/Strings.lua")

local L = Strings.Get

local Hud = {}
Hud.__index = Hud
Hud.Widgets = { "(hud)" }

local CONFIRM_MS = 8000 -- the reminder alone takes about 3 s to say
local ARMED_SETTLE_MS = 1200 -- the park (up to 600 ms after a click, then ~750 ms); a potion drunk
-- by its key sets the armed slot for ~400 ms too

-- OnArmed(action) (Game/Hotbar.ArmedAction): set by Setup/Commands.
Hud.OnArmed = nil

-- One armed spell of the game (from armed to not armed): followed once, by the mod's own
-- targeting (Hud.Followed) or here. Module state: HUD instances come and go with other screens.
-- The cursor resting on an enemy (where the mod's targeting left it) looks exactly like an armed
-- main-hand attack (Activate.Park): the cursor is parked first, and only an action still armed
-- after that was armed by the player.
local followed, armedAt, parked = false, nil, false
-- Which armed action was followed: another one armed without the state ever going empty (a
-- thrown handaxe's "Lanzar" right after a cancelled attack that stayed armed, 2026-09-25) is
-- followed anew.
local followedKey = nil
local function armedKey()
    local a = Hotbar.ArmedAction()
    return a and table.concat({ tostring(a.id), tostring(a.name), tostring(a.object and a.object.uuid) }, "|") or nil
end

-- The mod's targeting took the armed action in hand.
function Hud.Followed()
    followed = true
end

-- The mod's targeting was closed by a game screen with the action still armed: follow it again.
function Hud.FollowAgain()
    followed, armedAt, parked, followedKey = false, nil, false, nil
end

-- Resources worth a confirmation (movement alone is often left over on purpose).
local MAIN_RESOURCES = { ActionPoint = true, BonusActionPoint = true }

function Hud.New()
    return setmetatable({ confirmUntil = 0 }, Hud)
end

function Hud:Open() end

function Hud:Tick()
    if not Hotbar.Armed() then
        followed, armedAt, parked, followedKey = false, nil, false, nil
        return
    end
    if followed then
        local key = armedKey()
        followedKey = followedKey or key
        if key == followedKey then return end
        followed, armedAt, parked, followedKey = false, nil, false, nil
    end
    local now = Ext.Timer.MonotonicTime()
    if not parked then
        parked, armedAt = true, now
        Activate.Park()
        return
    end
    if now - armedAt < ARMED_SETTLE_MS then return end
    local a = Hotbar.ArmedAction()
    -- Only an action that can be used now (before the park existed, the cursor left on a target
    -- after a spell looked like an armed main-hand attack with no action left, 2026-09-25).
    if a and a.canUse and a.useType ~= "Potion" and Hud.OnArmed then
        followed = true
        Hud.OnArmed(a)
    end
end

-- Ctrl+R in game: the controlled character's status.
function Hud:ReadAll()
    local me = Characters.Snapshot(Player.SelectedCharacter())
    Speech.Say(me and Words.Status(me) or L("no_screen"), { interrupt = true })
end

function Hud:Help()
    return { L("help_hud") }
end

-- Names of the main resources the controlled character still has, e.g. { "Acción adicional" }.
local function leftOver()
    local me = Characters.Snapshot(Player.SelectedCharacter())
    local out = {}
    for _, r in ipairs(me and me.resources or {}) do
        if MAIN_RESOURCES[r.id or ""] and (r.value or 0) > 0 then out[#out + 1] = r.name or r.id end
    end
    return out
end

function Hud:OnKey(combo)
    if combo ~= "SPACE" or not Config.Get("combat.confirmEndTurn") then return false end
    if not (Combat.Current() and Player.IsCurrentTurn()) then return false end
    local now = Ext.Timer.MonotonicTime()
    if now < self.confirmUntil then
        self.confirmUntil = 0
        return false -- the game's end turn
    end
    local left = leftOver()
    if #left == 0 then return false end
    self.confirmUntil = now + CONFIRM_MS
    Speech.Say(L("end_turn_confirm", { left = Strings.List(left) }), { interrupt = true })
    return true
end

return Hud
