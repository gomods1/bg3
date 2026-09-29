-- Spell data from the game's stats (client), for describing what an armed action would do.
-- Facts (verified 2026-09-24 with Ext.Stats.Get): SpellType (Target, Projectile, Shout, Zone,
-- Throw, Teleportation, ...); TargetRadius (range, meters; empty for Shout/Zone); AreaRadius (an
-- explosion or area around the point: Projectile_Fireball 4, Target_Grease 4); Zone spells: Shape
-- Cone (Range = length, Angle = degrees: Zone_Cleave 2 m / 120, Zone_BurningHands 5 m / 60) or
-- Square (Range = length, Base = width: Zone_Thunderwave 5 x 5). TooltipDamageList
-- "RegainHitPoints(1d4+...)" for heals (Target_HealingWord), "DealDamage(...)" for damage;
-- SpellRoll.Default "Attack(...)" or "not SavingThrow(Ability.Dexterity, ...)" (Sacred Flame).
-- Items that cast (scrolls): the item entity's SpellBook.Spells[1].Id.Prototype (verified: scroll
-- of revivify -> Teleportation_Revivify_Scroll). Potions have no SpellBook: using one drinks it.
local Entities = Ext.Require("Game/Entities.lua")
local Loca = Ext.Require("Game/Loca.lua")

local Spells = {}

local function field(stat, name)
    local ok, v = pcall(function() return stat[name] end)
    if ok then return v end
    return nil
end

local function number(v)
    v = tonumber(v)
    if v and v > 0 then return v end
    return nil
end

-- { id, type, range?, radius?, shape? ("Cone"/"Square"), length?, width?, angle?, heals,
--   damages (can deal damage: an attack roll or DealDamage), attack (an attack roll), save? (the
--   saving throw's ability, in the game's language) } or nil.
function Spells.Info(id)
    if not id or id == "" then return nil end
    local ok, stat = pcall(Ext.Stats.Get, id)
    if not ok or not stat then return nil end
    local info = {
        id = id,
        type = tostring(field(stat, "SpellType") or ""),
        range = number(field(stat, "TargetRadius")),
        radius = number(field(stat, "AreaRadius")),
    }
    local damageList = tostring(field(stat, "TooltipDamageList") or "")
    info.heals = damageList:find("RegainHitPoints", 1, true) ~= nil
    local params = tostring(field(stat, "DescriptionParams") or "")
    info.damages = damageList:find("DealDamage", 1, true) ~= nil or params:find("DealDamage", 1, true) ~= nil
    local roll = field(stat, "SpellRoll")
    local rollText = ""
    pcall(function() rollText = tostring(roll.Default or "") end)
    info.attack = rollText:find("Attack(", 1, true) ~= nil
    info.damages = info.damages or info.attack -- weapon attacks list no damage of their own
    local ability = rollText:match("SavingThrow%(Ability%.(%a+)")
    info.save = ability and (Loca.Enum("AbilityDisplayName", ability) or ability) or nil
    if info.type == "Zone" then
        info.shape = tostring(field(stat, "Shape") or "")
        info.length = number(field(stat, "Range"))
        info.width = number(field(stat, "Base"))
        info.angle = number(field(stat, "Angle"))
    end
    return info
end

-- "only" when the spell can only be used in combat (Rage), "never" when never in combat (Arcane
-- Recovery), nil otherwise: the stat's Requirements entry "Combat" with its Not flag.
function Spells.CombatRule(id)
    local ok, stat = pcall(Ext.Stats.Get, id)
    if not ok or not stat then return nil end
    local rule = nil
    pcall(function()
        for _, r in ipairs(stat.Requirements or {}) do
            if tostring(r.Requirement) == "Combat" then rule = r.Not and "never" or "only" end
        end
    end)
    return rule
end

-- Statuses (or status groups, "SG_Rage") the spell's RequirementConditions ask the caster to have:
-- the plain HasStatus('X') terms not negated ("HasStatus('SG_Rage') and ..." for Ferocious
-- Appetite, verified 2026-09-26). Terms with a second argument (another target) are left out.
function Spells.RequiredStatuses(id)
    local ok, stat = pcall(Ext.Stats.Get, id)
    if not ok or not stat then return {} end
    local text = ""
    pcall(function() text = tostring(stat.RequirementConditions or "") end)
    local out = {}
    for before, name in text:gmatch("(%a*)%s*HasStatus%('([%w_]+)'%)") do
        if before ~= "not" then out[#out + 1] = name end
    end
    return out
end

-- Whether the spell may target its own caster: its TargetConditions do not say "not Self()"
-- (Lesser Restoration may, Magic Missile and weapon attacks may not). Unknown spells: false.
function Spells.CanTargetSelf(id)
    local ok, stat = pcall(Ext.Stats.Get, id or "")
    if not ok or not stat then return false end
    local text = ""
    pcall(function() text = tostring(stat.TargetConditions or "") end)
    return not text:find("not%s+Self%(%)")
end

-- Spell stat id for a display-name handle (view models such as ls.VMSpellReference carry only the
-- name: Spell.Name, Level). Several stats share a name (Zone_BurningHands, Zone_BurningHands_4
-- upcast variants, item and monster copies); the base spell comes first in GetStats order
-- (verified), and level picks among them. Built once: 4614 spells, 12 ms.
local idsByName = nil
function Spells.IdByName(handle, level)
    if not handle then return nil end
    if not idsByName then
        idsByName = {}
        for _, id in ipairs(Ext.Stats.GetStats("SpellData")) do
            local stat = Ext.Stats.Get(id)
            local h = stat and field(stat, "DisplayName")
            if h and h ~= "" then
                local list = idsByName[h] or {}
                list[#list + 1] = id
                idsByName[h] = list
            end
        end
    end
    local list = idsByName[tostring(handle)]
    if not list then return nil end
    for _, id in ipairs(list) do
        if level == nil or tonumber(field(Ext.Stats.Get(id), "Level")) == level then return id end
    end
    return list[1]
end

-- Description parameters ("DealDamage(3d6,Fire);Distance(18)") as data: { kind = "damage", dice,
-- min, max, damageType (game language) } / { kind = "heal", dice, min, max } / { kind = "distance",
-- meters } / { kind = "text", text } (anything else: its first argument, as the game has it).
local function diceRange(dice)
    local n, d, plus = tostring(dice):match("^(%d*)d(%d+)%s*([%+%-]?%s*%d*)$")
    if not d then
        local flat = tonumber(dice)
        return flat, flat
    end
    n, d = tonumber(n ~= "" and n or "1"), tonumber(d)
    local bonus = tonumber(((plus or ""):gsub("%s", ""))) or 0
    return n + bonus, n * d + bonus
end

local function parseParam(p)
    local fn, args = p:match("^%s*([%w_]+)%((.*)%)%s*$")
    if not fn then return { kind = "text", text = p } end
    local a = {}
    for part in (args .. ","):gmatch("([^,]*),") do a[#a + 1] = part:match("^%s*(.-)%s*$") end
    if fn == "DealDamage" then
        local min, max = diceRange(a[1])
        local t = a[2] and (Loca.Enum("DamageTypeNameTemplate", a[2]) or a[2])
        return { kind = "damage", dice = a[1], min = min, max = max, damageType = t }
    elseif fn == "RegainHitPoints" then
        local min, max = diceRange(a[1])
        return { kind = "heal", dice = a[1], min = min, max = max }
    elseif fn == "Distance" then
        return { kind = "distance", meters = tonumber(a[1]) }
    end
    return { kind = "text", text = a[1] or p }
end

-- A stat's DescriptionParams ("Distance(4.5);DealDamage(1d6,Fire)") as parseParam results, in
-- order: the values of "[1]", "[2]"... in its description.
function Spells.ParseParams(text)
    local out = {}
    for p in (tostring(text or "") .. ";"):gmatch("([^;]*);") do
        if p ~= "" then out[#out + 1] = parseParam(p) end
    end
    return out
end

-- The game's title for a spell's school and level, as its tooltip shows it: "Truco de evocación"
-- (cantrip), "Conjuro de evocación niv. 1" (Tooltips.xaml SpellSchoolTitle; the school names of
-- LearnSpells.xaml are wrong in Spanish: Enchantment reads "Escuela de Abjuración"). nil if unknown.
function Spells.Title(school, level)
    if not school or school == "" or school == "None" then return nil end
    if level == 0 then return Loca.Enum("SpellSchoolTitle.GroupType=Cantrip", school) end
    local t = Loca.Enum("SpellSchoolTitle.IsSpell=True", school)
    return t and (t:gsub("%[1%]", tostring(level or ""))) or nil
end

local COSTS = { ActionPoint = "action", BonusActionPoint = "bonus", ReactionActionPoint = "reaction" }

-- What the spell's tooltip says, as data (words are the caller's):
-- { name, level (0 = cantrip), title (Spells.Title), description (template with [1]...),
--   params = { parseParam results }, costs = { "action"|"bonus"|"reaction" }, slotLevel?,
--   range?, radius?, attack, save?, heals, concentration, ritual } or nil.
function Spells.Details(id)
    local info = Spells.Info(id)
    if not info then return nil end
    local stat = Ext.Stats.Get(id)
    local out = info
    out.name = Loca.Get(field(stat, "DisplayName"))
    out.level = tonumber(field(stat, "Level")) or 0
    out.title = Spells.Title(tostring(field(stat, "SpellSchool") or ""), out.level)
    out.description = Loca.Get(field(stat, "Description"))
    out.params = Spells.ParseParams(field(stat, "DescriptionParams"))
    out.costs = {}
    for cost in tostring(field(stat, "UseCosts") or ""):gmatch("[^;]+") do
        local name, rest = cost:match("^([%w]+):?(.*)$")
        if COSTS[name] then out.costs[#out.costs + 1] = COSTS[name] end
        if name == "SpellSlotsGroup" then out.slotLevel = tonumber(rest:match("(%d+)$")) end
    end
    local flags = {}
    pcall(function() for _, f in pairs(field(stat, "SpellFlags") or {}) do flags[tostring(f)] = true end end)
    out.concentration = flags.IsConcentration == true
    out.ritual = flags.IsRitual == true
    if not out.range and out.type ~= "Zone" then out.range = number(field(stat, "Range")) end
    return out
end

-- The spell an item casts when used (scrolls), or nil (potions and other items used at once).
function Spells.OfItem(uuid)
    local e = Entities.Get(uuid)
    local ok, id = pcall(function() return e.SpellBook.Spells[1].Id.Prototype end)
    if ok and id and id ~= "" then return tostring(id) end
    return nil
end

return Spells
