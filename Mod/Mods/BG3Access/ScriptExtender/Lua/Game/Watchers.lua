-- Who can see a character (server Osiris CanSee(observer, target) and CanSpotSneakers(observer),
-- Server/Queries): what a sighted player judges from the sneak vision cones (Left Shift held).
local Channels = Ext.Require("Net/Channels.lua")
local Entities = Ext.Require("Game/Entities.lua")
local Interactables = Ext.Require("Game/Interactables.lua")

local Watchers = {}

local RADIUS = 40 -- meters
local MAX_DY = 15

-- The living characters outside the party around the controlled character that see it:
-- onResult({ { uuid, name, spotsSneakers } }), nearest first.
function Watchers.Of(onResult)
    local me = Entities.Controlled()
    local p = Entities.Position(me)
    if not p then
        onResult({})
        return
    end
    local around = {}
    for _, o in ipairs(Interactables.Near(p, RADIUS, MAX_DY)) do
        if o.category == "character" and o.uuid ~= me and not Entities.IsPartyMember(o.uuid) and not Entities.IsDead(o.uuid) then
            around[#around + 1] = o
        end
    end
    table.sort(around, function(a, b) return Entities.Distance(a.position, p) < Entities.Distance(b.position, p) end)
    local uuids = {}
    for _, o in ipairs(around) do uuids[#uuids + 1] = o.uuid end
    if #uuids == 0 then
        onResult({})
        return
    end
    Channels.Watchers:RequestToServer({ uuids = uuids, target = me }, function(reply)
        local out = {}
        for _, o in ipairs(around) do
            local r = reply and reply[o.uuid]
            if r and r.sees then out[#out + 1] = { uuid = o.uuid, name = o.name, spotsSneakers = r.spotsSneakers } end
        end
        onResult(out)
    end)
end

return Watchers
