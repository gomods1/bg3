-- Traps (client): items with the Disarmable component ("Trampa de pinchos", "Trampa de red de
-- espinas", gas vents: verified 2026-09-24 on the Risen Road). Whether the party has discovered
-- one lives on the server (Osiris IsTrapDiscovered, Net/Channels TrapStates). An undiscovered
-- trap is invisible to a sighted player, so the mod's lists leave it out; a discovered one is
-- named as a trap and never walked onto by Enter.
local Entities = Ext.Require("Game/Entities.lua")
local Channels = Ext.Require("Net/Channels.lua")

local Traps = {}

function Traps.IsTrap(uuid)
    local e = Entities.Get(uuid)
    if not e then return false end
    local ok, c = pcall(function() return e.Disarmable end)
    return ok and c and true or false -- not "~= nil": engine objects compare through __eq
end

-- onResult({ [uuid] = { discovered } }) on a later frame.
function Traps.States(uuids, onResult)
    Channels.TrapStates:RequestToServer({ uuids = uuids }, function(reply) onResult(reply or {}) end)
end

return Traps
