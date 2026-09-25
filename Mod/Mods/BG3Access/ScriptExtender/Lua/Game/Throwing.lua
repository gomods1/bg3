-- What a character can pick up to throw (the Throw action's first step). Facts (verified
-- 2026-09-25, Tav, Strength 17, Blighted Village): the game refuses characters of 75 kg and more
-- ("Pesa demasiado, no se puede lanzar") and static furniture whatever its weight ("El objetivo no
-- puede moverse por la fuerza": a 20 kg table), whose server flag IsMovable is 0; heavy movable
-- items cannot even be hovered in throw mode (a 50 kg pile of books). A 5 kg chair was thrown.
-- The weight limit, Strength x ExtraData ThrowWeightMultiplier (2) kg, is a **hypothesis** that
-- fits these cases (34 kg for Tav); no movable item between 34 and 75 kg was tried.
-- Weights: the entity's Data.Weight in grams (client).
local Items = Ext.Require("Game/Items.lua")

local Throwing = {}

local STRENGTH = 2 -- Stats.Abilities[] follows AbilityId from None (verified: Tav 0, 17, 13, 15, 8, 12, 10)

local function weightKg(uuid)
    local ok, w = pcall(function() return Ext.Entity.Get(uuid).Data.Weight end)
    return ok and type(w) == "number" and w / 1000 or nil
end

-- The heaviest thing (kg) character uuid can throw, or nil when unknown.
function Throwing.LimitKg(uuid)
    local ok, strength = pcall(function() return Ext.Entity.Get(uuid).Stats.Abilities[STRENGTH] end)
    local multiplier = Ext.Stats.GetStatsManager().ExtraData.ThrowWeightMultiplier
    if not (ok and type(strength) == "number" and multiplier) then return nil end
    return strength * multiplier
end

-- Whether thrower can pick up the thing with uuid to throw it. Items need the server's answer
-- (Game/Items.Fetch: movable); while it is unknown the thing counts as throwable (not hidden).
function Throwing.CanThrow(thrower, uuid, isCharacter)
    local limit, w = Throwing.LimitKg(thrower), weightKg(uuid)
    if limit and w and w > limit then return false end
    if isCharacter then return true end
    local info = Items.WorldInfo(uuid)
    return not (info and info.movable == false)
end

return Throwing
