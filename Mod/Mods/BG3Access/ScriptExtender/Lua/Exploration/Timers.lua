-- Announces story timers (Game/StoryTimer) as the minimap shows them to a sighted player: the
-- objective and the turns left when one appears, then every change of the turns left (or of the
-- counter), queued as events. Timers.Words() is also used by the status readouts.
local StoryTimer = Ext.Require("Game/StoryTimer.lua")
local Speech = Ext.Require("Core/Speech.lua")
local Strings = Ext.Require("Core/Strings.lua")
local Log = Ext.Require("Core/Log.lua")

local L = Strings.Get

local Timers = {}

local POLL_MS = 500

local last = nil -- { id, value } of the timer last announced

local function valueWords(t)
    if t.total then
        return L("timer_count", { what = t.countText or "", n = t.count, total = t.total })
    end
    return L("timer_turns_left", { n = t.turnsLeft })
end

-- "¡Alcanza el transpondedor...! 15 turns left", or nil without a timer.
function Timers.Words()
    local t = StoryTimer.Read()
    if not t then return nil end
    return Strings.Sentences({ t.text, valueWords(t) })
end

local function poll()
    local t = StoryTimer.Read()
    if not t then
        last = nil
        return
    end
    local value = t.total and t.count or t.turnsLeft
    if last and last.id == t.id then
        if last.value ~= value then Speech.Event(valueWords(t)) end
    else
        Speech.Event(Strings.Sentences({ t.text, valueWords(t) }))
    end
    last = { id = t.id, value = value }
end

function Timers.Start()
    local lastPoll = 0
    Ext.Events.Tick:Subscribe(function()
        local now = Ext.Timer.MonotonicTime()
        if now - lastPoll < POLL_MS then return end
        lastPoll = now
        Log.Guard("story timers", poll)
    end)
end

return Timers
