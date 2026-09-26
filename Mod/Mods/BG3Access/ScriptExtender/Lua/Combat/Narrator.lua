-- Speaks the game's combat log as it grows (Game/CombatLog). Every raw line goes to the Events and
-- Combat review buffers; what is spoken depends on config combat.log:
--   "full"     every line, as the game writes it.
--   "grouped"  (default; template_rpg: coalesce floods per actor) lines are gathered into units
--              (an action and its results) and said compactly (Combat/LogWords). The party's own
--              actions and round lines are said as soon as their unit is complete; other actors'
--              units are gathered per actor and said as one announcement when another actor
--              acts, when the log goes quiet, or before a turn is announced (Combat/Tracker calls
--              Narrator.Flush), so the player's turn never waits behind the enemies' tail.
-- Queued, never interrupting. Entries present when the mod starts or a save loads are not read
-- back: during a loading screen and for LOAD_QUIET_MS after it the log is only counted (measured:
-- after the nautiloid's level change the game refilled the log with the old fight's entries).
local CombatLog = Ext.Require("Game/CombatLog.lua")
local CombatState = Ext.Require("Game/Combat.lua")
local Player = Ext.Require("Game/Player.lua")
local LogWords = Ext.Require("Combat/LogWords.lua")
local Speech = Ext.Require("Core/Speech.lua")
local Buffers = Ext.Require("Core/Buffers.lua")
local Config = Ext.Require("Core/Config.lua")
local Log = Ext.Require("Core/Log.lua")
local Router = Ext.Require("Screens/Router.lua")

local Narrator = {}

local POLL_MS = 200
local LOAD_QUIET_MS = 5000
local UNIT_QUIET_MS = 700   -- a unit's results arrive with the animation; then it is complete
local GROUP_QUIET_MS = 1500 -- an actor's gathered units are said after this much silence
local LOADING_SCREEN = "root"

local quietUntil = 0
local seen = nil      -- entries already handled; nil until the first poll sets the baseline
-- The game logs some lines twice, not always in a row ("Han curado a Carnicero Vrak un total de
-- 7 puntos de golpe." and "Asalto de combate 3." with another line between, 2026-09-25): a line
-- equal to one taken within REPEAT_MS is dropped.
local REPEAT_MS = 1500
local recent = {}     -- text -> when it was taken
local lastEntryAt = 0
local unit = nil      -- the unit being built: { head = entry?, results = { entries } }
local group = nil     -- gathered units of one actor: { actor, units = { } }
-- Statuses each non-party actor gave itself in its last group ([actor][status] = true): losing
-- one right after its turn (Dash, "Correr") is not worth a line after the next turn's announcement.
local selfStatuses = {}
local now = {}        -- complete units to say at the end of this poll (LogWords.Many)

local function grouped()
    return Config.Get("combat.log") ~= "full"
end

local function flushNow()
    if #now == 0 then return end
    Speech.Say(LogWords.Many(now))
    now = {}
end

local function flushGroup()
    flushNow()
    if not group then return end
    Speech.Say(LogWords.Group(group.units))
    group = nil
end

-- A complete unit: said now (party, rounds, lines about nobody) or gathered by actor. A line on
-- its own about a character (a status lost at the end of its turn) goes with that character.
local function route(u)
    local h = u.head
    local actor = h and ((h.kind == "action" and h.actor) or (h.kind ~= "round" and h.subject))
    if not actor or Player.PartyNames()[actor] then
        if group then flushGroup() end
        now[#now + 1] = u
        return
    end
    flushNow()
    if h.kind == "statusRemoved" and h.status and (selfStatuses[actor] or {})[h.status] then
        return -- kept in the buffers only
    end
    if group and group.actor ~= actor then flushGroup() end
    if not group then
        group = { actor = actor, units = {} }
        selfStatuses[actor] = {}
    end
    for _, r in ipairs(u.results) do
        if r.kind == "statusAdded" and r.subject == actor and r.status then selfStatuses[actor][r.status] = true end
    end
    group.units[#group.units + 1] = u
end

local function closeUnit()
    if unit then route(unit) end
    unit = nil
end

-- Barks are spoken by the speech.barks setting: "all", "party" (the party's own) or "none".
-- Volo's song in the goblin camp was a line every few seconds over everything else (2026-09-24).
-- A bark said again within BARK_REPEAT_MS is not spoken again (still in the History buffer): Volo
-- sings his ten lines over and over, a new line every 5 s (goblin camp, 2026-09-25).
local BARK_REPEAT_MS = 5 * 60 * 1000
local barkSaidAt = {}
local function barkWanted(e)
    local mode = Config.Get("speech.barks") or "all"
    if mode == "none" then return false end
    if mode == "party" and not (e.speaker ~= nil and Player.PartyNames()[e.speaker] == true) then return false end
    local now = Ext.Timer.MonotonicTime()
    local last = barkSaidAt[e.text]
    if last and now - last < BARK_REPEAT_MS then return false end
    barkSaidAt[e.text] = now
    return true
end

-- Outside combat the same line again within BARK_REPEAT_MS is not spoken again either: a goblin
-- throwing rocks for fun ("Skrut: Lanzar roca.") every few seconds by Minthara, 2026-09-25.
local lineSaidAt = {}
local function repeatedOutsideCombat(e)
    if CombatState.Current() then return false end
    local now = Ext.Timer.MonotonicTime()
    local last = lineSaidAt[e.text]
    lineSaidAt[e.text] = now
    return last ~= nil and now - last < BARK_REPEAT_MS
end

local function take(e)
    if e.kind == "speech" and not barkWanted(e) then
        Buffers.Add("events", e.text)
        return
    end
    Buffers.Add("events", e.text)
    if e.kind ~= "speech" and repeatedOutsideCombat(e) then return end
    Buffers.Add("combat", e.text)
    if not grouped() then
        Speech.Say(e.text)
        return
    end
    local result = e.kind ~= "action" and e.kind ~= "round" and e.subject ~= nil
    if e.depth == 0 and result and unit and unit.head and unit.head.kind == "action" then
        -- Lines about someone right after an action, logged on their own: the action's results
        -- ("Tav ha recibido el estado «Ataque temerario»." after the reaction; the saves and
        -- "Derribado" of everyone caught in a goblin's Grease, gate fight 2026-09-24).
        unit.results[#unit.results + 1] = e
    elseif e.depth == 0 then
        closeUnit()
        unit = { head = e, results = {} }
    elseif unit then
        unit.results[#unit.results + 1] = e
    else
        unit = { results = { e } } -- results whose action line came before a flush
    end
end

local function readNew()
    local count = CombatLog.Count()
    local now = Ext.Timer.MonotonicTime()
    if Router.current == LOADING_SCREEN then quietUntil = now + LOAD_QUIET_MS end
    if now < quietUntil then
        seen = count
        return
    end
    if seen == nil or count < seen then
        seen = count -- first poll, or the log restarted (a save was loaded)
        return
    end
    if count == seen then return end
    for _, e in ipairs(CombatLog.Entries(seen + 1)) do
        -- Hits and misses repeat for real: Scorching Ray's two rays of 6 were said as one
        -- (torture room, 2026-09-25).
        local mayRepeat = e.kind == "damage" or e.kind == "miss"
        if e.text and e.text ~= "" and (mayRepeat or not (recent[e.text] and now - recent[e.text] < REPEAT_MS)) then take(e) end
        if e.text then recent[e.text] = now end
    end
    for text, at in pairs(recent) do
        if now - at >= REPEAT_MS then recent[text] = nil end
    end
    seen = count
    lastEntryAt = now
end

local function poll()
    readNew()
    local quiet = Ext.Timer.MonotonicTime() - lastEntryAt
    if unit and quiet >= UNIT_QUIET_MS then closeUnit() end
    flushNow()
    if group and quiet >= GROUP_QUIET_MS then flushGroup() end
end

-- Says everything gathered so far (before a turn line, so the turn is heard last).
function Narrator.Flush()
    Log.Guard("combat narrator flush", function()
        readNew()
        closeUnit()
        flushGroup()
    end)
end

function Narrator.Start()
    local last = 0
    Ext.Events.Tick:Subscribe(function()
        local now = Ext.Timer.MonotonicTime()
        if now - last < POLL_MS then return end
        last = now
        Log.Guard("combat narrator", poll)
    end)
end

return Narrator
