-- Things near a point that a sighted player could click, beyond what the game's highlight shows
-- (Game/Highlights leaves out scenery: 23 usable items within 30 m of the nautiloid's brain-tank
-- room, none highlighted; measured 2026-09-24). Sources (client components):
--   items with a UseAction component (chairs, tanks, tablets, levers, containers...);
--   items that can be picked up (CanBeInInventory) lying in the world;
--   both only when not inside an inventory (InventoryMember) and with a display name;
--   characters (ClientCharacter), party members included (clicking a companion talks to them:
--   the camp's conversations), except the character the player controls.
-- Categories (Interactables.Category): character, door (IsDoor), trap (Disarmable: Game/Traps),
-- container (InventoryOwner: barrels, backpacks, pouches on the beach), loot (can be picked up),
-- other.
-- Rule from the user (2026-09-24): nothing a sighted player can reach may be left out because the
-- highlight skips it. OPEN QUESTION: how the client marks objects that are hidden until found
-- (perception checks, secret doors, traps); until that is known these are listed like the rest.
local Entities = Ext.Require("Game/Entities.lua")

local Interactables = {}

-- Names the game uses for internal helpers ("%%% Brain Reader"): never listed.
local function playerFacing(name)
    return name and name ~= "" and not name:find("^%%")
end

local function has(e, component)
    local ok, c = pcall(function() return e[component] end)
    return ok and c and true or false -- not "~= nil": engine objects compare through __eq
end

-- "character", "door", "trap", "container", "loot" or "other" for the entity with this UUID.
function Interactables.Category(uuid)
    local e = Entities.Get(uuid)
    if not e then return "other" end
    if has(e, "ClientCharacter") then return "character" end
    if has(e, "IsDoor") then return "door" end
    if has(e, "Disarmable") then return "trap" end
    if has(e, "InventoryOwner") then return "container" end
    if has(e, "CanBeInInventory") then return "loot" end
    return "other"
end

local function collect(out, seen, component, p, radius, maxDy, accept)
    for _, e in ipairs(Ext.Entity.GetAllEntitiesWithComponent(component)) do
        local ok, uuid = pcall(function() return e.Uuid.EntityUuid end)
        local pos = ok and uuid and not seen[uuid] and Entities.Position(uuid)
        if pos and Entities.Distance(pos, p) <= radius and math.abs(pos[2] - p[2]) <= maxDy and accept(e) then
            local name = Entities.Name(uuid)
            if playerFacing(name) then
                seen[uuid] = true
                out[#out + 1] = { uuid = uuid, name = name, position = pos, category = Interactables.Category(uuid) }
            end
        end
    end
end

-- { { uuid, name, position, category } } within radius meters (ground distance) of p and maxDy
-- meters above or below it. Doors are left to Game/Doors (their state comes from the server).
function Interactables.Near(p, radius, maxDy)
    local out, seen = {}, {}
    local function worldItem(e)
        return not has(e, "InventoryMember") and not has(e, "ClientCharacter") and not has(e, "IsDoor")
    end
    collect(out, seen, "UseAction", p, radius, maxDy, worldItem)
    collect(out, seen, "CanBeInInventory", p, radius, maxDy, worldItem)
    local me = Entities.Controlled()
    collect(out, seen, "ClientCharacter", p, radius, maxDy, function(e)
        local ok, uuid = pcall(function() return e.Uuid.EntityUuid end)
        return not (ok and uuid == me)
    end)
    return out
end

-- Objects that can be attacked (a destructible with a Health component and hit points left,
-- lying in the world): { { uuid, name, position } } within radius of p. E.g. "Base debilitada"
-- (5 hp) under Lae'zel's cage: breaking it lets the cage down (verified 2026-09-24, it is not a
-- UseAction item, so the other lists leave it out).
function Interactables.Attackable(p, radius, maxDy)
    local out, seen = {}, {}
    collect(out, seen, "Health", p, radius, maxDy, function(e)
        if has(e, "InventoryMember") or has(e, "ClientCharacter") then return false end
        local ok, hp = pcall(function() return e.Health.Hp end)
        return ok and hp and hp > 0
    end)
    return out
end

return Interactables
