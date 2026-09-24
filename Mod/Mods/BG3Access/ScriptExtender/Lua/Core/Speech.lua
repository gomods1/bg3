-- Speech requests. The native bridge owns Prism; this only formats messages.
-- Never interrupt by default (template_rpg rule 4).
local Bridge = Ext.Require("Core/Bridge.lua")

local Speech = {}

-- opts: { interrupt = bool, channel = string, ttl = ms }
function Speech.Say(text, opts)
    if text == nil or text == "" then return end
    opts = opts or {}
    Bridge.Send(string.format("say %d %s %d %s",
        opts.interrupt and 1 or 0, opts.channel or "-", opts.ttl or 0, Bridge.Escape(text)))
end

function Speech.Stop()
    Bridge.Send("stop")
end

return Speech
