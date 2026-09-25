-- The player's marks (client half of Server/Marks): spots on this level kept with the save.
-- Every call answers with the marks of the controlled character's level: { { id, name, position } }.
local Channels = Ext.Require("Net/Channels.lua")
local Entities = Ext.Require("Game/Entities.lua")

local Marks = {}

local function ask(data, onResult)
    data.character = Entities.Controlled()
    Channels.Marks:RequestToServer(data, function(reply)
        if onResult then onResult(reply and reply.marks or {}) end
    end)
end

function Marks.List(onResult)
    ask({ op = "list" }, onResult)
end

function Marks.Add(name, position, onResult)
    ask({ op = "add", name = name, position = { position[1], position[2], position[3] } }, onResult)
end

function Marks.Remove(id, onResult)
    ask({ op = "remove", id = id }, onResult)
end

return Marks
