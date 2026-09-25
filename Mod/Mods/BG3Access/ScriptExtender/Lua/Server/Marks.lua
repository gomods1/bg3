-- The player's own marks (server half): spots the player marked to come back to (the blind
-- player's custom map markers: the game's need a click on the map), kept in the savegame.
local Channels = Ext.Require("Net/Channels.lua")
local Log = Ext.Require("Core/Log.lua")

local Marks = {}

local VAR = "Marks" -- { { id, name, position = {x,y,z}, level } }, saved with the game

local function vars()
    return Ext.Vars.GetModVariables(ModuleUUID)
end

local function levelOf(uuid)
    local ok, name = pcall(function() return Ext.Entity.Get(uuid).Level.LevelName end)
    return ok and name or nil
end

local function all()
    return vars()[VAR] or {}
end

local function save(list)
    vars()[VAR] = list -- mod variables are saved only when assigned
end

local function handle(data)
    local list = all()
    local level = levelOf(data.character)
    if data.op == "add" and type(data.name) == "string" and type(data.position) == "table" then
        local id = 0
        for _, m in ipairs(list) do id = math.max(id, m.id or 0) end
        list[#list + 1] = { id = id + 1, name = data.name, position = data.position, level = level }
        save(list)
    elseif data.op == "remove" then
        local keep = {}
        for _, m in ipairs(list) do
            if m.id ~= data.id then keep[#keep + 1] = m end
        end
        save(keep)
        list = keep
    end
    local out = {}
    for _, m in ipairs(list) do
        if m.level == level then out[#out + 1] = { id = m.id, name = m.name, position = m.position } end
    end
    return { marks = out }
end

-- Before any save is loaded (the variable must exist when the game reads the save).
function Marks.Register()
    Ext.Vars.RegisterModVariable(ModuleUUID, VAR, { Server = true, Client = false, SyncToClient = false })
end

function Marks.Start()
    Channels.Marks:SetRequestHandler(function(data)
        local ok, reply = pcall(handle, data)
        if not ok then
            Log.Error("marks: " .. tostring(reply))
            return { marks = {} }
        end
        return reply
    end)
end

return Marks
