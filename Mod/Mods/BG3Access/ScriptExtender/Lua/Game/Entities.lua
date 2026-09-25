-- Entities (client): lookup by UUID, position, display name. Keep UUIDs, never entity objects:
-- they expire at the end of the tick.
-- Facts (SE v32, verified 2026-09-24): Ext.Entity.Get(uuid); e.Transform.Transform.Translate is the
-- world position (y up, meters); e.DisplayName.NameKey.Handle.Handle is the name handle; client
-- characters have the "ClientCharacter" component (ecl::Character).
local Player = Ext.Require("Game/Player.lua")
local Vm = Ext.Require("Game/Vm.lua")

local Entities = {}

function Entities.Get(uuid)
    if not uuid then return nil end
    local ok, e = pcall(Ext.Entity.Get, uuid)
    if ok then return e end
    return nil
end

-- { x, y, z } or nil.
function Entities.Position(uuid)
    local e = Entities.Get(uuid)
    local ok, t = pcall(function() return e.Transform.Transform.Translate end)
    if ok and t then return { t[1], t[2], t[3] } end
    return nil
end

function Entities.Name(uuid)
    local e = Entities.Get(uuid)
    local ok, s = pcall(function() return Ext.Loca.GetTranslatedString(e.DisplayName.NameKey.Handle.Handle) end)
    if ok and s and s ~= "" then return s end
    return nil
end

-- UUID of the character the local player controls: the UI's selected character (F1-F4, or the
-- game's own pick when the party's turn starts). The ClientControl component is not it: in the
-- nautiloid fight it stayed on Tav while Lae'zel was selected (verified 2026-09-24). Falls back to
-- ClientControl when the UI has no selected character (loading).
function Entities.Controlled()
    local uuid = Vm.Get(Player.SelectedCharacter(), "EntityUUID")
    if uuid and uuid ~= "" then return tostring(uuid) end
    for _, e in ipairs(Ext.Entity.GetAllEntitiesWithComponent("ClientControl")) do
        local ok, uuid = pcall(function() return e.Uuid.EntityUuid end)
        if ok and uuid then return uuid end
    end
    return nil
end

-- true for doors (the IsDoor tag component).
function Entities.IsDoor(uuid)
    local e = Entities.Get(uuid)
    local ok, c = pcall(function() return e.IsDoor end)
    return ok and c and true or false
end

-- true for ladders (portal items with the Ladder component: "Escalera de hierro", "Malla arterial").
function Entities.IsLadder(uuid)
    local e = Entities.Get(uuid)
    local ok, c = pcall(function() return e.Ladder end)
    return ok and c and true or false
end

-- true for passages: items that take the character elsewhere when used (the ItemPortal component:
-- "Entrada al cubil de huargos", "Entrada al santuario destrozado", cave entrances).
function Entities.IsPassage(uuid)
    local e = Entities.Get(uuid)
    local ok, c = pcall(function() return e.ItemPortal end)
    return ok and c and true or false
end

-- true for characters (the ClientCharacter component), false for items and anything else.
function Entities.IsCharacter(uuid)
    local e = Entities.Get(uuid)
    local ok, c = pcall(function() return e.ClientCharacter end)
    return ok and c and true or false
end

-- true for the party's own characters (the PartyMember component).
function Entities.IsPartyMember(uuid)
    local e = Entities.Get(uuid)
    local ok, c = pcall(function() return e.PartyMember end)
    return ok and c and true or false
end

-- The "!" over a character who wants to talk (a companion after a scene, a camp request): the
-- story's PROC_ExclamationMark_Show plays a VFX and sets the tag HAS_EXCLAMATION_DIALOG
-- (_GLOBAL_Shared_RelationshipDialogs); the tag reaches the client (verified 2026-09-24: Gale and
-- Shadowheart after Kagha's scene, save 24).
local EXCLAMATION_TAG = "e45ea222-a86f-4e00-a1ca-98d8b258b1ce"

function Entities.WantsToTalk(uuid)
    local e = Entities.Get(uuid)
    local ok, found = pcall(function()
        for _, t in ipairs(e.Tag.Tags) do
            if t == EXCLAMATION_TAG then return true end
        end
        return false
    end)
    return ok and found == true
end

-- Characters within radius meters of point p who want to talk: { uuid }.
function Entities.WantingToTalk(p, radius)
    local out = {}
    for _, e in ipairs(Ext.Entity.GetAllEntitiesWithComponent("ClientCharacter")) do
        local ok, uuid = pcall(function() return e.Uuid.EntityUuid end)
        local pos = ok and Entities.Position(uuid)
        if pos and Entities.Distance(pos, p) <= radius and Entities.WantsToTalk(uuid) then out[#out + 1] = uuid end
    end
    return out
end

-- The visual's world box { min = {x,y,z}, max = {x,y,z} } (Visual.Visual.WorldBound), or nil.
function Entities.WorldBound(uuid)
    local e = Entities.Get(uuid)
    local ok, b = pcall(function()
        local w = e.Visual.Visual.WorldBound
        return { min = { w.Min[1], w.Min[2], w.Min[3] }, max = { w.Max[1], w.Max[2], w.Max[3] } }
    end)
    if ok then return b end
    return nil
end

-- true for a character with no hit points left (Health.Hp 0: corpses on the beach, verified).
-- Hit points and maximum (the Health component: characters and destructible objects), or nil.
function Entities.Health(uuid)
    local e = Entities.Get(uuid)
    local ok, hp, max = pcall(function() return e.Health.Hp, e.Health.MaxHp end)
    if ok and hp then return hp, max end
    return nil
end

-- Whether character uuid has status id (the client's StatusContainer: status entity -> id).
function Entities.HasStatus(uuid, id)
    local e = uuid and Entities.Get(uuid)
    local found = false
    pcall(function()
        for _, name in pairs(e.StatusContainer.Statuses) do
            if name == id then found = true end
        end
    end)
    return found
end

function Entities.IsDead(uuid)
    local e = Entities.Get(uuid)
    local ok, hp = pcall(function() return e.Health.Hp end)
    return ok and hp ~= nil and hp <= 0
end

-- Ground distance in meters between two points { x, y, z } (height ignored).
function Entities.Distance(a, b)
    return math.sqrt((a[1] - b[1]) ^ 2 + (a[3] - b[3]) ^ 2)
end

-- Stable text identity of an entity object for comparisons within a tick ("Entity (01c0...)").
function Entities.Handle(e)
    if not e then return nil end
    return tostring(e)
end

return Entities
