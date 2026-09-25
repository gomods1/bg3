-- Read signposts (server half): what each sign the party read said (Game/Signposts catches the
-- reader's line), kept in the savegame for the client's Signposts list, like Server/Places.
local Channels = Ext.Require("Net/Channels.lua")
local Log = Ext.Require("Core/Log.lua")

local Signposts = {}

local VAR = "ReadSignposts" -- { [sign uuid] = what its reader said }, saved with the game

local function vars()
    return Ext.Vars.GetModVariables(ModuleUUID)
end

local function levelOf(entity)
    local ok, name = pcall(function() return entity.Level.LevelName end)
    return ok and name or nil
end

local function positionOf(entity)
    local ok, t = pcall(function() return entity.Transform.Transform.Translate end)
    return ok and t and { t[1], t[2], t[3] } or nil
end

-- { { uuid, text, position } } for the read signs on the level of character uuid.
local function readOnLevel(characterUuid)
    local character = Ext.Entity.Get(characterUuid)
    local level = character and levelOf(character)
    local out = {}
    for uuid, text in pairs(vars()[VAR] or {}) do
        local sign = Ext.Entity.Get(uuid)
        local position = sign and positionOf(sign)
        if position and type(text) == "string" and levelOf(sign) == level then
            out[#out + 1] = { uuid = uuid, text = text, position = position }
        end
    end
    return out
end

-- Before any save is loaded (the variable must exist when the game reads the save).
function Signposts.Register()
    Ext.Vars.RegisterModVariable(ModuleUUID, VAR, { Server = true, Client = false, SyncToClient = false })
end

function Signposts.Start()
    Channels.RememberSignpost:SetRequestHandler(function(data)
        if type(data.uuid) == "string" and type(data.text) == "string" and data.text ~= "" then
            local all = vars()
            local read = all[VAR] or {}
            read[data.uuid] = data.text
            all[VAR] = read -- mod variables are saved only when assigned
        end
        return {}
    end)
    Channels.Signposts:SetRequestHandler(function(data)
        local ok, list = pcall(readOnLevel, data.character)
        if not ok then
            Log.Error("signposts: " .. tostring(list))
            return { signposts = {} }
        end
        return { signposts = list }
    end)
end

return Signposts
