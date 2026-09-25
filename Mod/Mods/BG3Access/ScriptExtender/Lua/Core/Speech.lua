-- Speech requests. The native bridge owns Prism; this only formats messages.
-- Never interrupt by default (template_rpg rule 4): interrupt only for direct answers to a key the
-- player just pressed (list moves, value changes), where the old line is stale anyway.
local Bridge = Ext.Require("Core/Bridge.lua")
local Buffers = Ext.Require("Core/Buffers.lua")

local Speech = {}

Speech.last = nil -- last line spoken, for the repeat key

-- opts: { interrupt = bool, channel = string, ttl = ms }
function Speech.Say(text, opts)
    if text == nil or text == "" then return end
    opts = opts or {}
    Speech.last = text
    Bridge.Send(string.format("say %d %s %d %s",
        opts.interrupt and 1 or 0, opts.channel or "-", opts.ttl or 0, Bridge.Escape(text)))
end

-- An unsolicited announcement: spoken (queued, never interrupting) and recorded in the Events
-- buffer, and in buffer too when given ("combat", "dialogue"; Core/Buffers).
function Speech.Event(text, buffer)
    if text == nil or text == "" then return end
    Speech.Say(text)
    Buffers.Add("events", text)
    if buffer then Buffers.Add(buffer, text) end
end

function Speech.Repeat()
    if Speech.last then Speech.Say(Speech.last, { interrupt = true }) end
end

-- Asks the bridge to pick the best speech backend again (e.g. the screen reader was restarted).
function Speech.ResetBackend()
    Bridge.Send("speech reset")
end

function Speech.Stop()
    Bridge.Send("stop")
end

return Speech
