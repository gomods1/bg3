-- How a spell is spoken. Line: the short form for lists ("Manos ardientes, Conjuro de evocación
-- niv. 1": the game's own title, Game/Spells.Title). Details (details key): what the game's
-- tooltip says, from Game/Spells.Details: cost, range or area, the roll, concentration, and the
-- game's description with its values filled in ("... sufre 3 to 18 Fuego damage.").
local Spells = Ext.Require("Game/Spells.lua")
local Strings = Ext.Require("Core/Strings.lua")
local Text = Ext.Require("Core/Text.lua")

local L = Strings.Get

local SpellWords = {}

-- spell = { name, title?, level? }; more parts (state words) may follow. Without the game's
-- title (school unknown) a levelled spell's level is said in the mod's words; level 0 without a
-- school is a class action (Arcane Recovery), not a cantrip: nothing is added.
function SpellWords.Line(spell, ...)
    local title = spell.title
    if not title and spell.level and spell.level > 0 then title = L("spell_level", { n = spell.level }) end
    return Strings.List({ spell.name or "?", title, ... })
end

local function paramText(p)
    if p.kind == "damage" and p.min and p.max then
        return L(p.damageType and "spell_param_damage_type" or "spell_param_damage", { min = p.min, max = p.max, type = p.damageType })
    elseif p.kind == "heal" and p.min and p.max then
        return L("spell_param_heal", { min = p.min, max = p.max })
    elseif p.kind == "distance" and p.meters then
        return L("meters", { n = p.meters })
    end
    return p.dice or p.text or ""
end

-- The game's description d.description with "[1]", "[2]"... replaced by d.params (Game/Spells
-- ParseParams), cleaned for speech; nil without a description.
function SpellWords.Description(d)
    if not d.description then return nil end
    local s = d.description:gsub("%[(%d+)%]", function(i)
        local p = d.params[tonumber(i)]
        return p and paramText(p) or ""
    end)
    return Text.Clean(s)
end

local function area(d)
    if d.shape == "Cone" and d.length then
        return d.angle and L("spell_cone_angle", { n = d.length, angle = d.angle }) or L("spell_cone", { n = d.length })
    elseif d.shape == "Square" and d.length then
        return L("spell_square", { n = d.length, width = d.width or d.length })
    elseif d.radius then
        return L("spell_radius", { n = d.radius })
    end
    return nil
end

-- Spoken details of spell stat id, or nil when the stats are unknown.
function SpellWords.Details(id)
    local d = Spells.Details(id)
    if not d then return nil end
    local costs = {}
    for _, c in ipairs(d.costs) do costs[#costs + 1] = L("cost_" .. c) end
    if d.slotLevel then costs[#costs + 1] = L("spell_slot_cost", { n = d.slotLevel }) end
    return Strings.Sentences({
        SpellWords.Line(d),
        Strings.List(costs),
        Strings.List({ d.range and L("spell_range", { n = d.range }), area(d) }),
        d.save and L("save_only", { ability = d.save }) or (d.attack and L("spell_attack_roll")),
        d.concentration and L("spell_concentration"),
        d.ritual and L("spell_ritual"),
        SpellWords.Description(d),
    })
end

return SpellWords
