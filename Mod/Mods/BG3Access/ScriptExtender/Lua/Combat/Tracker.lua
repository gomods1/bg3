-- Combat announcements (template_rpg 17.1), polled from the turn order (Game/Combat): combat start
-- ("Combat: 3 enemies"), whose turn it is (the party acts together: "Turn: Tav, Lae'zel", with the
-- controlled character's resources on the party's turn), combat end. Never interrupts.
-- Also the switch to another party member (F1-F4, [ ], a portrait): "Now Lae'zel", or her status
-- line in combat.
local Combat = Ext.Require("Game/Combat.lua")
local Characters = Ext.Require("Game/Characters.lua")
local Player = Ext.Require("Game/Player.lua")
local Words = Ext.Require("Combat/Words.lua")
local Narrator = Ext.Require("Combat/Narrator.lua")
local Speech = Ext.Require("Core/Speech.lua")
local Strings = Ext.Require("Core/Strings.lua")
local Log = Ext.Require("Core/Log.lua")

local L = Strings.Get

local Tracker = {}

local POLL_MS = 200
local END_DELAY_MS = 600

local state = { combat = nil, turnKey = nil, selected = nil, switchAt = nil, turnAt = 0 }

-- The game selects a party member itself when the party's turn starts; the turn line already says
-- who it is, so a switch within SWITCH_QUIET_MS of a turn line is not announced separately.
local SWITCH_QUIET_MS = 800

local function pollSelected(now)
    local vm = Player.SelectedCharacter()
    local me = vm and Characters.Snapshot(vm)
    local uuid = me and me.uuid
    if not uuid then return end -- loading, menus: keep the last one (no announcement on return)
    if state.selected and uuid ~= state.selected then state.switchAt = now end
    state.selected = uuid
    if state.switchAt and now - state.switchAt >= SWITCH_QUIET_MS then
        state.switchAt = nil
        if now - state.turnAt < 2 * SWITCH_QUIET_MS then return end
        -- In combat the status line starts with the name.
        local line = Combat.Current() and Words.Status(me) or L("now_controlling", { name = me.name or "?" })
        Speech.Say(line, { interrupt = true })
    end
end

local function poll()
    local now = Ext.Timer.MonotonicTime()
    local id = Combat.Current()
    if id ~= state.combat then
        if id then
            local enemies = 0
            for _, c in ipairs(Combat.Combatants()) do
                if c.relation == "Enemy" then enemies = enemies + 1 end
            end
            Speech.Event(L("combat_started", { n = enemies }), "combat")
        elseif state.combat then
            -- After the narrator has spoken the last log lines (the kill that ended the fight).
            Ext.Timer.WaitForRealtime(END_DELAY_MS, function() Speech.Event(L("combat_ended"), "combat") end)
        end
        state.combat, state.turnKey = id, nil
    end
    if id then
        local names, partyTurn, acting = {}, false, {}
        for _, c in ipairs(Combat.Combatants()) do
            if c.currentTurn then
                names[#names + 1] = c.name or "?"
                if c.relation == "Player" then
                    partyTurn = true
                    acting[#acting + 1] = c
                end
            end
        end
        local key = table.concat(names, ",")
        if key ~= state.turnKey and #names > 0 then
            state.turnKey = key
            Narrator.Flush() -- the last actor's gathered log lines come before the new turn
            local line = L("turn_of", { names = Strings.List(names) })
            if partyTurn then
                -- The status of the selected character when it is one of those acting, else of
                -- the first of them ("Turn: Gale" once read Tav's status: the game had not
                -- switched the selection yet, gate fight 2026-09-24).
                local selected = Characters.Snapshot(Player.SelectedCharacter())
                local me = acting[1]
                for _, c in ipairs(acting) do
                    if selected and c.uuid == selected.uuid then me = selected end
                end
                if me then line = Strings.Sentences({ line, Words.Status(me) }) end
                state.turnAt = now
            end
            Speech.Event(line, "combat")
        end
    end
    pollSelected(now)
end

function Tracker.Start()
    local last = 0
    Ext.Events.Tick:Subscribe(function()
        local now = Ext.Timer.MonotonicTime()
        if now - last < POLL_MS then return end
        last = now
        Log.Guard("combat tracker", poll)
    end)
end

return Tracker
