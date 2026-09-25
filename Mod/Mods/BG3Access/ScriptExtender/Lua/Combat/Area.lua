-- Who an area action would catch (template_rpg 17.1: "who is in the area"), estimated from the
-- spell's shape in the stats (Game/Spells) and the combatants' positions: a sphere of AreaRadius
-- around the point (Fireball, Grease), or a zone from the caster toward the point (a cone of
-- Range and Angle: Cleave, Burning Hands; a square of Range by Base: Thunderwave). Sighted players
-- see the game's highlight; this is the same picture in words, allies included (the game hits them
-- too unless the spell says otherwise). A body counts when its middle is within BODY_MARGIN of the
-- shape. Estimates only: the game's own preview decides.
local Combat = Ext.Require("Game/Combat.lua")
local Entities = Ext.Require("Game/Entities.lua")
local Spells = Ext.Require("Game/Spells.lua")

local Area = {}

local BODY_MARGIN = 0.5 -- meters
local RADIUS_TYPES = { Target = true, Projectile = true, Shout = true }

-- The area of spell id, or nil when it has none (single target, self).
function Area.Of(id)
    local info = Spells.Info(id)
    if not info then return nil end
    if info.type == "Zone" and info.length and (info.shape == "Cone" and info.angle or info.shape == "Square" and info.width) then
        return info
    end
    -- AreaRadius means an area only for these types (a Teleportation spell's is its reach:
    -- the scroll of revivify has 9).
    if info.radius and RADIUS_TYPES[info.type] then return info end
    return nil
end

local function inside(area, origin, point, p)
    if area.type ~= "Zone" then
        return Entities.Distance(point, p) <= area.radius + BODY_MARGIN
    end
    local ax, az = point[1] - origin[1], point[3] - origin[3]
    local len = math.sqrt(ax * ax + az * az)
    if len < 0.01 then return false end
    ax, az = ax / len, az / len
    local dx, dz = p[1] - origin[1], p[3] - origin[3]
    local along = dx * ax + dz * az
    local across = math.abs(dx * az - dz * ax) -- distance from the axis
    if area.shape == "Square" then
        return along >= -BODY_MARGIN and along <= area.length + BODY_MARGIN and across <= area.width / 2 + BODY_MARGIN
    end
    local dist = math.sqrt(dx * dx + dz * dz)
    if dist > area.length + BODY_MARGIN or dist < 0.01 then return false end
    local angle = math.deg(math.acos(math.max(-1, math.min(1, along / dist))))
    local margin = math.deg(math.asin(math.min(1, BODY_MARGIN / dist)))
    return angle <= area.angle / 2 + margin
end

-- Combatants (Game/Characters snapshots) inside the area of spell id cast by caster (UUID) at
-- point { x, y, z }; nil when the spell has no area. The caster is included when inside (a
-- fireball at one's feet), except for zones, which start at the caster.
function Area.Catches(id, caster, point)
    local area = Area.Of(id)
    if not area then return nil end
    local origin = Entities.Position(caster)
    if not origin then return nil end
    local out = {}
    for _, c in ipairs(Combat.Combatants()) do
        local p = c.uuid and Entities.Position(c.uuid)
        local isCaster = c.uuid == caster
        if p and (c.hp or 0) > 0 and not (isCaster and area.type == "Zone") and inside(area, origin, point, p) then
            out[#out + 1] = c
        end
    end
    return out
end

return Area
