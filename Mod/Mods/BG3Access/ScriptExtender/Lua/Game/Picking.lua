-- What the game's cursor picking sees (client, player 1): the object a click would act on.
-- Facts (SE v32, verified 2026-09-24): Ext.UI.GetPickingHelper(1).Inner.Inner[1].GameObject is the
-- hovered entity (a lying mind flayer showed there with Character = nil); Inner.Position is the
-- ground point under the cursor.
local Picking = {}

local PLAYER = 1

local function helper()
    local ok, ph = pcall(Ext.UI.GetPickingHelper, PLAYER)
    if ok then return ph end
    return nil
end

-- The hovered entity object (valid this tick), or nil.
function Picking.Hovered()
    local ph = helper()
    local ok, go = pcall(function() return ph.Inner.Inner[1].GameObject end)
    if ok then return go end
    return nil
end

-- true when the entity with this UUID is under the cursor, as the hovered game object, item,
-- character or dead character.
function Picking.IsHovered(uuid)
    local ph = helper()
    local ok, hit = pcall(function()
        local inner = ph.Inner.Inner[1]
        for _, e in ipairs({ inner.GameObject, inner.Item, inner.Character, inner.DeadCharacter }) do
            if e and e.Uuid and e.Uuid.EntityUuid == uuid then return true end
        end
        return false
    end)
    return ok and hit
end

-- UUID of the item or character under the cursor (what a click would act on), or nil.
function Picking.HoveredObjectUuid()
    local ph = helper()
    local ok, uuid = pcall(function()
        local inner = ph.Inner.Inner[1]
        local e = inner.Item or inner.Character or inner.DeadCharacter
        return e and e.Uuid and e.Uuid.EntityUuid
    end)
    if ok then return uuid end
    return nil
end

-- Ground point under the cursor { x, y, z }, or nil.
function Picking.Ground()
    local ph = helper()
    local ok, p = pcall(function() return ph.Inner.Position end)
    if ok and p then return { p[1], p[2], p[3] } end
    return nil
end

return Picking
