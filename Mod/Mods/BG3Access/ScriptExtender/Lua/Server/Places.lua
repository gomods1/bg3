-- Named places (server half): the game's sub-areas ("Estanque sagrado", "El Hueco") the party has
-- entered, remembered in the savegame, for the client's Places list (Exploration/Places).
-- Facts (verified 2026-09-24, SE v32): the story declares each sub-area as
-- DB_Subregion(trigger, key, showMarker, level) or DB_SubregionMarker(trigger, key, marker, level)
-- (Shared _GLOBAL_Subregions goal; Act1_Subregions ...); the party member's current one is
-- DB_Subregion_Current(character, trigger); the key names a translated string
-- (Ext.Loca.GetTranslatedStringKey("DEN_SacredPond_SUB") -> the handle of "Estanque sagrado"),
-- the same name the game shows on entering. The trigger is an area trigger entity; many are
-- irregular polygons (El Hueco, "DEN_Cave_SUB", is 130 m across): their centre says little, so
-- each place keeps where the party member stood on entering it, a walkable spot inside it.
-- Places not yet entered stay out of the list, as the map's shroud hides them from a sighted
-- player (a sub-area can be a secret: "DEN_SecretLibrary_SUB").
local Channels = Ext.Require("Net/Channels.lua")
local Log = Ext.Require("Core/Log.lua")

local Places = {}

local VAR = "VisitedPlaces" -- { [trigger uuid] = { x, y, z } where it was entered }, saved with the game

-- Osiris hands triggers as "S_DEN_SacredPond_SUB_2303e19f-549f-434f-bee0-b886fb34c46a".
local function uuidOf(osirisGuid)
    return tostring(osirisGuid):sub(-36)
end

local function vars()
    return Ext.Vars.GetModVariables(ModuleUUID)
end

local function positionOf(uuid)
    local e = Ext.Entity.Get(uuid)
    local ok, t = pcall(function() return e.Transform.Transform.Translate end)
    return ok and t and { t[1], t[2], t[3] } or nil
end

-- The latest entry point: the way the party last came in.
local function remember(character, trigger)
    local at = positionOf(uuidOf(character))
    if not at then return end
    local all = vars()
    local visited = all[VAR] or {}
    visited[uuidOf(trigger)] = at
    all[VAR] = visited -- mod variables are saved only when assigned
end

-- Key of a sub-area's name: a renamed marker first (PROC_Subregion_Rename updates it), else the
-- key it was declared with.
local function nameKeys()
    local keys = {}
    for _, row in ipairs(Osi.DB_Subregion:Get(nil, nil, nil, nil)) do keys[uuidOf(row[1])] = row[2] end
    for _, row in ipairs(Osi.DB_SubregionMarker:Get(nil, nil, nil, nil)) do keys[uuidOf(row[1])] = row[2] end
    return keys
end

local function levelOf(entity)
    local ok, name = pcall(function() return entity.Level.LevelName end)
    return ok and name or nil
end

-- { { name, position = {x,y,z} (where it was entered), current = bool } } for the visited
-- sub-areas on the level of character uuid.
local function visitedPlaces(characterUuid)
    local visited = vars()[VAR] or {}
    for _, row in ipairs(Osi.DB_Subregion_Current:Get(nil, nil)) do
        if type(visited[uuidOf(row[2])]) ~= "table" then remember(row[1], row[2]) end
    end
    local character = Ext.Entity.Get(characterUuid)
    local level = character and levelOf(character)
    local current = {}
    for _, row in ipairs(Osi.DB_Subregion_Current:Get(characterUuid, nil)) do current[uuidOf(row[2])] = true end
    local keys, out, seen = nameKeys(), {}, {}
    for uuid, at in pairs(vars()[VAR] or {}) do
        local trigger = Ext.Entity.Get(uuid)
        local key = keys[uuid]
        local handle = key and Ext.Loca.GetTranslatedStringKey(key)
        local name = handle and Ext.Loca.GetTranslatedString(handle)
        -- One entry per name (a place can be made of several triggers: the chapel's floors).
        if trigger and type(at) == "table" and name and name ~= "" and levelOf(trigger) == level and not seen[name] then
            seen[name] = true
            out[#out + 1] = { name = name, position = { at[1], at[2], at[3] }, current = current[uuid] == true }
        end
    end
    return out
end

-- Before any save is loaded (the variable must exist when the game reads the save).
function Places.Register()
    Ext.Vars.RegisterModVariable(ModuleUUID, VAR, { Server = true, Client = false, SyncToClient = false })
end

function Places.Start()
    Ext.Osiris.RegisterListener("DB_Subregion_Current", 2, "after", function(character, trigger)
        local ok, err = pcall(remember, character, trigger)
        if not ok then Log.Error("places: " .. tostring(err)) end
    end)
    Channels.Places:SetRequestHandler(function(data)
        local ok, list = pcall(visitedPlaces, data.character)
        if not ok then
            Log.Error("places: " .. tostring(list))
            return { places = {} }
        end
        return { places = list }
    end)
end

return Places
