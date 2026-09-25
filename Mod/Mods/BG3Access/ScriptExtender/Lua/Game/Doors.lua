-- Doors (client): door entities carry the tag component IsDoor (eoc::item::DoorComponent); their
-- open/locked state lives on the server (Net/Channels DoorStates -> Server/Queries).
-- A door opens and closes with a click on it, like any interactable (Game/Activate).
local Entities = Ext.Require("Game/Entities.lua")
local Channels = Ext.Require("Net/Channels.lua")

local Doors = {}

-- Doors within radius meters of point p: { { uuid, name, position } }.
function Doors.Near(p, radius)
    local out = {}
    for _, e in ipairs(Ext.Entity.GetAllEntitiesWithComponent("IsDoor")) do
        local ok, uuid = pcall(function() return e.Uuid.EntityUuid end)
        local pos = ok and Entities.Position(uuid)
        if pos and Entities.Distance(pos, p) <= radius then
            out[#out + 1] = { uuid = uuid, name = Entities.Name(uuid), position = pos }
        end
    end
    return out
end

-- Asks the server for the doors' states; onResult({ [uuid] = { opened, locked } }) on a later frame.
function Doors.States(uuids, onResult)
    Channels.DoorStates:RequestToServer({ uuids = uuids }, function(reply) onResult(reply or {}) end)
end

return Doors
