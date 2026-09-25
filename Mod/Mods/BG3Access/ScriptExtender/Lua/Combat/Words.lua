-- How characters are spoken in combat and status readouts (Game/Characters snapshots). Only what
-- the game shows a sighted player: names, relation, HP (the game shows enemy HP), resources.
local Entities = Ext.Require("Game/Entities.lua")
local Direction = Ext.Require("Exploration/Direction.lua")
local Strings = Ext.Require("Core/Strings.lua")

local L = Strings.Get

local Words = {}

local function n(v) return math.floor((v or 0) + 0.5) end

local RELATIONS = { Enemy = "relation_enemy", Player = "relation_party", Neutral = "relation_neutral", Ally = "relation_ally" }

function Words.Hp(s)
    if s.hp and s.hp <= 0 then return L("hp_none") end
    return L("hp", { value = n(s.hp), max = n(s.maxHp) })
end

-- "Furia, 10 turns, Bendición" (the game's status names), or nil when there are none.
function Words.Statuses(s)
    local parts = {}
    for _, st in ipairs(s.statuses or {}) do
        if st.name then
            parts[#parts + 1] = st.turns and L("status_turns", { name = st.name, n = st.turns }) or st.name
        end
    end
    if #parts == 0 then return nil end
    return Strings.List(parts)
end

-- "Diablillo, enemy, 6 of 6 HP, 5 meters, Furia 10 turns"
function Words.Combatant(s)
    local parts = { s.name or "?" }
    local rel = RELATIONS[s.relation or ""]
    if rel then parts[#parts + 1] = L(rel) end
    parts[#parts + 1] = Words.Hp(s)
    local me = Entities.Position(Entities.Controlled())
    local p = s.uuid and Entities.Position(s.uuid)
    if me and p and s.uuid ~= Entities.Controlled() then
        parts[#parts + 1] = L("meters", { n = n(Entities.Distance(me, p)) })
        parts[#parts + 1] = Direction.Words(me, p)
    end
    parts[#parts + 1] = Words.Statuses(s)
    return Strings.List(parts)
end

-- "Tav, 14 of 14 HP. Acción 1 of 1, ... Movement 9 of 9 meters. Furia, 10 turns."
function Words.Status(s)
    local res = {}
    for _, r in ipairs(s.resources) do
        res[#res + 1] = L("resource", { name = r.name or r.id or "?", value = n(r.value), max = n(r.max) })
    end
    for _, sl in ipairs(s.slots or {}) do
        res[#res + 1] = L("spell_slots", { level = sl.level or 0, value = n(sl.value), max = n(sl.max) })
    end
    if s.maxMovement and s.maxMovement > 0 then
        res[#res + 1] = L("movement", { value = n(s.movement), max = n(s.maxMovement) })
    end
    return Strings.Sentences({
        L("status_line", { name = s.name or "?", hp = Words.Hp(s), resources = Strings.List(res) }),
        Words.Statuses(s),
    })
end

-- The game's preview for an armed action (Game/Preview) as words: "not possible, 65 percent to hit,
-- 4 to 9 damage, walks 3 meters first, 6 left". moveKey says what the movement cost means for this
-- action (default "walks_first": the walk before a targeted action; a jump's cost is the jump).
-- spell: Game/Spells.Info of the armed action, when known: heals are said as healing, a saving
-- throw's chance as the chance it works.
function Words.Preview(p, moveKey, spell)
    local parts = {}
    if not p.canExecute then parts[#parts + 1] = L("target_invalid") end
    for _, m in ipairs(p.messages or {}) do parts[#parts + 1] = m end
    if spell and spell.save then
        parts[#parts + 1] = p.hitChance and L("save_chance", { n = p.hitChance, ability = spell.save })
            or L("save_only", { ability = spell.save })
    elseif p.hitChance and not (spell and spell.heals and not spell.attack) then
        parts[#parts + 1] = L("hit_chance", { n = p.hitChance })
    end
    if p.advantages > 0 then parts[#parts + 1] = L("advantage") end
    if p.disadvantages > 0 then parts[#parts + 1] = L("disadvantage") end
    -- The damage preview keeps its last value: say it only for actions that can deal damage
    -- (Help on an enemy once read "6 to 17 damage" from an earlier attack).
    if p.damageMax and (not spell or spell.damages or spell.heals) then
        parts[#parts + 1] = L(spell and spell.heals and "heal_range" or "damage_range", { min = p.damageMin, max = p.damageMax })
    end
    if p.moveCost then parts[#parts + 1] = L(moveKey or "walks_first", { n = n(p.moveCost), left = n(p.moveLeft) }) end
    if p.opportunityAttack then parts[#parts + 1] = L("opportunity_attack") end
    if p.lethal then parts[#parts + 1] = L("lethal") end
    if p.surface then parts[#parts + 1] = p.surface end
    return Strings.List(parts)
end

-- "in the area: Diablillo, Lae'zel, party" (Combat/Area results); except: a UUID left out (the
-- target itself, already spoken).
function Words.AreaCatches(caught, except)
    local names = {}
    for _, c in ipairs(caught) do
        if c.uuid ~= except then
            local rel = c.relation ~= "Enemy" and RELATIONS[c.relation or ""]
            names[#names + 1] = rel and L("name_relation", { name = c.name or "?", relation = L(rel) }) or c.name or "?"
        end
    end
    if #names == 0 then return except and nil or L("area_nobody") end
    return L("area_catches", { names = Strings.List(names) })
end

return Words
