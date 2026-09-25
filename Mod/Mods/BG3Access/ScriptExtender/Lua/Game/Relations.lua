-- How characters stand toward the party: "enemy", "ally" or "neutral" (server Osiris IsEnemy /
-- IsAlly toward the controlled character, Server/Queries). Out of combat the client has no such
-- view model (combatants carry PlayerRelation); a sighted player sees hostile names in red.
-- Asked again each time a list opens (hostility changes), kept by uuid until then.
local Channels = Ext.Require("Net/Channels.lua")
local Entities = Ext.Require("Game/Entities.lua")

local Relations = {}

local known = {}

-- Asks the server about the characters with these uuids; onDone() when known.
function Relations.Fetch(uuids, onDone)
    if #uuids == 0 then
        onDone()
        return
    end
    Channels.Relations:RequestToServer({ uuids = uuids, to = Entities.Controlled() }, function(reply)
        for u, r in pairs(reply or {}) do known[u] = r end
        onDone()
    end)
end

-- "enemy", "ally", "neutral" or nil (not asked yet).
function Relations.Of(uuid)
    return known[uuid]
end

return Relations
