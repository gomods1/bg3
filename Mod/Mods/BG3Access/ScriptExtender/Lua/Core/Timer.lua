-- Short waits driven by the game's Tick event. SE's Ext.Timer.WaitForRealtime fires in steps of
-- ~233 ms whatever the delay (measured 2026-09-24: 50 ms -> 233, 100 ms -> 465, 60 ms polls every
-- 232 ms), while Tick runs every frame (~80 ms at the dev machine's rate). Hover and click checks
-- poll with this so they follow the game within a frame.
local Log = Ext.Require("Core/Log.lua")

local Timer = {}

local pending = {} -- { at = ms, fn = function }
local subscribed = false

local function onTick()
    if #pending == 0 then return end
    local now = Ext.Timer.MonotonicTime()
    local due = {}
    for i = #pending, 1, -1 do
        if pending[i].at <= now then
            due[#due + 1] = pending[i].fn
            table.remove(pending, i)
        end
    end
    for i = #due, 1, -1 do Log.Guard("timer", due[i]) end
end

-- Calls fn on the first frame at least ms milliseconds from now.
function Timer.After(ms, fn)
    if not subscribed then
        Ext.Events.Tick:Subscribe(onTick)
        subscribed = true
    end
    pending[#pending + 1] = { at = Ext.Timer.MonotonicTime() + ms, fn = fn }
end

return Timer
