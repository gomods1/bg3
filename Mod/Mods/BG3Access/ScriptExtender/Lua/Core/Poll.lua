-- Polling on the game's Tick, in one place. The mod watches the game by reading its view models a
-- few times a second (the screen router, the combat tracker, the log narrator, the HUD notices,
-- stealth, story timers): each poller says how often it wants to run and gets called from a single
-- Tick subscriber, in registration order, guarded (an error in one poller never stops the others).
-- The time each poller takes is kept (Poll.Report, for the dev channel: which poller costs what),
-- so a slow tick can be traced to its cause instead of guessed at.
local Log = Ext.Require("Core/Log.lua")

local Poll = {}

local pollers = {} -- { name, ms, fn, last, calls, total, max }
local subscribed = false

local function onTick()
    local now = Ext.Timer.MonotonicTime()
    for _, p in ipairs(pollers) do
        if now - p.last >= p.ms then
            p.last = now
            local t0 = Ext.Timer.MicrosecTime()
            Log.Guard(p.name, p.fn)
            local took = (Ext.Timer.MicrosecTime() - t0) / 1000
            p.calls = p.calls + 1
            p.total = p.total + took
            if took > p.max then p.max = took end
        end
    end
end

-- Runs fn at most every ms milliseconds (on the first Tick after the interval), starting now.
-- name labels errors and the report.
function Poll.Every(name, ms, fn)
    assert(type(fn) == "function", "poller " .. tostring(name) .. " needs a function")
    pollers[#pollers + 1] = { name = name, ms = ms, fn = fn, last = -math.huge, calls = 0, total = 0, max = 0 }
    if not subscribed then
        subscribed = true
        Ext.Events.Tick:Subscribe(onTick)
    end
end

-- { { name, ms, calls, totalMs, avgMs, maxMs } } in registration order.
function Poll.Stats()
    local out = {}
    for _, p in ipairs(pollers) do
        out[#out + 1] = {
            name = p.name, ms = p.ms, calls = p.calls, totalMs = p.total,
            avgMs = p.calls > 0 and p.total / p.calls or 0, maxMs = p.max,
        }
    end
    return out
end

-- One line per poller, for the dev channel: "router: 1200 calls, avg 0.8 ms, max 12.3 ms".
function Poll.Report()
    local lines = {}
    for _, s in ipairs(Poll.Stats()) do
        lines[#lines + 1] = string.format("%s (every %d ms): %d calls, avg %.2f ms, max %.1f ms, total %.0f ms",
            s.name, s.ms, s.calls, s.avgMs, s.maxMs, s.totalMs)
    end
    return table.concat(lines, "\n")
end

-- Forgets the counts (not the pollers).
function Poll.ResetStats()
    for _, p in ipairs(pollers) do p.calls, p.total, p.max = 0, 0, 0 end
end

return Poll
