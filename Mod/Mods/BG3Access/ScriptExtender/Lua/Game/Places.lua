-- Named places the party has been to on this level (the game's sub-areas, remembered in the save
-- by the server half: Server/Places). Asked through Net/Channels.
local Channels = Ext.Require("Net/Channels.lua")
local Entities = Ext.Require("Game/Entities.lua")

local Places = {}

-- onResult({ { name, position = {x,y,z}, radius, current } }) on a later frame.
function Places.Visited(onResult)
    Channels.Places:RequestToServer({ character = Entities.Controlled() }, function(reply)
        onResult(reply and reply.places or {})
    end)
end

return Places
