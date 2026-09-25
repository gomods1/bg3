-- Signposts. Reading one makes the reader say its directions (verified 2026-09-24, Risen Road:
-- Tav: «Oeste: Puerta de Baldur. Este: Elturel»), a bark in the combat log
-- (ls.VMAutomaticDialogEntry "[1]: [2]"). Signs are items with stats OBJ_Signpost (UseAction
-- StoryUse: the story plays the line; verified 2026-09-25, Blighted Village). What each read
-- sign said is kept with the save (Server/Signposts) for the Signposts list.
local Channels = Ext.Require("Net/Channels.lua")
local CombatLog = Ext.Require("Game/CombatLog.lua")
local Entities = Ext.Require("Game/Entities.lua")
local Timer = Ext.Require("Core/Timer.lua")

local Signposts = {}

local READ_WAIT_MS = 90000 -- the walk there comes first
local POLL_MS = 250

function Signposts.Is(uuid)
    local ok, id = pcall(function() return Ext.Entity.Get(uuid).Data.StatsId end)
    return ok and id == "OBJ_Signpost"
end

local watch = 0 -- the latest watch; an earlier one stops

-- The party is going to read sign uuid (a walk, then a click): the next line the controlled
-- character says within READ_WAIT_MS is what the sign says, and it is remembered.
function Signposts.WatchReading(uuid)
    watch = watch + 1
    local mine = watch
    local reader = Entities.Name(Entities.Controlled())
    local from = CombatLog.Count() + 1
    local started = Ext.Utils.MonotonicTime()
    local function poll()
        if watch ~= mine then return end
        local entries = CombatLog.Entries(from)
        for _, e in ipairs(entries) do
            if e.kind == "speech" and e.said and e.speaker == reader then
                Channels.RememberSignpost:RequestToServer({ uuid = uuid, text = e.said }, function() end)
                return
            end
        end
        from = from + #entries
        if Ext.Utils.MonotonicTime() - started < READ_WAIT_MS then Timer.After(POLL_MS, poll) end
    end
    Timer.After(POLL_MS, poll)
end

-- The read signs on the controlled character's level: onResult({ { uuid, text, position } }).
function Signposts.Read(onResult)
    Channels.Signposts:RequestToServer({ character = Entities.Controlled() }, function(reply)
        onResult(reply and reply.signposts or {})
    end)
end

return Signposts
