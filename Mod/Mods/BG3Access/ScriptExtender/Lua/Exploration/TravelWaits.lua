-- Waiting during a trip (Exploration/Travel): until the walker stops, a door opens, or a remark
-- said on the way is over.
local Entities = Ext.Require("Game/Entities.lua")
local Ui = Ext.Require("Game/Ui.lua")
local Doors = Ext.Require("Game/Doors.lua")
local Dialogue = Ext.Require("Game/Dialogue.lua")
local Timer = Ext.Require("Core/Timer.lua")

local TravelWaits = {}

local POLL_MS = 250
local STOPPED_MS = 750  -- no movement for this long = arrived or blocked
local SEGMENT_TIMEOUT_MS = 15000
local STILL_METERS = 0.05

-- While a dialogue is up: onGone() when it closes within REMARK_WAIT_MS without ever offering
-- answers (an ambient remark), else onScene() (a conversation, any other screen, or too long).
-- Shadowheart's two-line remark in the goblin sanctum took 16 s (2026-09-24): a conversation
-- that needs the player ends the walk anyway as soon as its answers come up.
local REMARK_WAIT_MS = 30000
local function afterRemark(onGone, onScene)
    local started = Ext.Utils.MonotonicTime()
    local function poll()
        local w = Ui.FrontBlockingWidget()
        if not w then
            onGone()
        elseif w.name ~= Dialogue.Widget or #Dialogue.Answers() > 0
            or Ext.Utils.MonotonicTime() - started > REMARK_WAIT_MS then
            onScene()
        else
            Timer.After(POLL_MS, poll)
        end
    end
    poll()
end

-- Calls andThen() once door uuid reads open on the server, or after DOOR_OPEN_WAIT_MS.
local DOOR_OPEN_WAIT_MS = 3000
local function whenDoorOpen(uuid, andThen)
    local started = Ext.Utils.MonotonicTime()
    local function poll()
        Doors.States({ uuid }, function(states)
            local st = states[uuid]
            if (st and st.opened) or Ext.Utils.MonotonicTime() - started > DOOR_OPEN_WAIT_MS then
                andThen()
            else
                Timer.After(POLL_MS, poll)
            end
        end)
    end
    poll()
end

-- Calls onStopped() once the controlled character has not moved for stoppedMs (default
-- STOPPED_MS) or the segment timed out.
local function waitUntilStopped(onStopped, stoppedMs)
    local me = Entities.Controlled()
    local last = Entities.Position(me)
    local still, elapsed = 0, 0
    local function poll()
        elapsed = elapsed + POLL_MS
        local p = Entities.Position(me)
        if p and last and Entities.Distance(p, last) < STILL_METERS then still = still + POLL_MS else still = 0 end
        last = p
        if still >= (stoppedMs or STOPPED_MS) or elapsed >= SEGMENT_TIMEOUT_MS then
            onStopped()
        else
            Ext.Timer.WaitForRealtime(POLL_MS, poll)
        end
    end
    Ext.Timer.WaitForRealtime(POLL_MS, poll)
end

TravelWaits.AfterRemark = afterRemark
TravelWaits.WhenDoorOpen = whenDoorOpen
TravelWaits.UntilStopped = waitUntilStopped

return TravelWaits
