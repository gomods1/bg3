-- The game's combat log (client): Data.CombatLog (gui::VMCombatLog).EntryGroups[] of
-- ls.CombatLogGroupedEntries { ChildDepth (0 = an action, 1 = its result), IsSeen,
-- CtxTransText (ls.VMContextTransString: Text template "[1] ha usado [2] con [3].",
-- Params[] { Text, Type Character/Spell/Damage/Round, RelationType, Rolls, DamageRolls }) }.
-- Verified 2026-09-24: "Tav ha usado Ataque con la mano hábil con Diablillo." and
-- "Diablillo ha recibido un impacto de 4 de daño cortante."
-- Each group's Entries[] are typed view models that say what the line is (verified in the
-- Gimblebock fight): ls.VMSpellEntry (an action: [actor] ha usado [spell] (con [target])),
-- VMHitDamagedEntry ([attacker]? [target] ha recibido un impacto de [damage]),
-- VMHitFailedEntry ([attacker] ha fallado [target]), VMHitResistedEntry ([target] + a Text param
-- "ha superado / ha fallado una tirada de salvación contra" + [spell]: passed and failed saves share
-- the type), VMStatusAddedEntry (depth 1) / VMStatusRemovedEntry (depth 0, at the end of the
-- actor's turn), VMHealedEntry, VMHitKilledDefenderEntry ([killer] ha matado a [target], depth 2)
-- followed by VMEntityDiedEntry (the same death again, depth 3), VMCombatNextRoundEntry,
-- VMXpGainedEntry, VMLevelChangeEntry, VMDialogStartEntry (no text). Params carry Type (Character, Spell, Damage, Text, Round...) and RelationType (Ally,
-- Enemy, Neutral) but no loca handles: phrases are only available translated.
local Vm = Ext.Require("Game/Vm.lua")
local Player = Ext.Require("Game/Player.lua")
local Text = Ext.Require("Core/Text.lua")

local CombatLog = {}

local function groups()
    return Vm.List(Vm.Get(Player.Data(), "CombatLog"), "EntryGroups")
end

-- Fills "[n]" with the n-th parameter's text.
local function render(ctx)
    local template = tostring(Vm.Get(ctx, "Text") or "")
    local params = Vm.List(ctx, "Params")
    local s = template:gsub("%[(%d+)%]", function(n)
        local p = params[tonumber(n)]
        return p and tostring(Vm.Get(p, "Text") or "") or ""
    end)
    return Text.Clean(s)
end

-- Number of entries so far (the log only grows during a session; it restarts on load).
function CombatLog.Count()
    return #groups()
end

local KINDS = {
    ["ls.VMSpellEntry"] = "action",
    ["ls.VMInterruptEntry"] = "action", -- a reaction: "Gimblebock ha usado Ataque de oportunidad"
    ["ls.VMHitDamagedEntry"] = "damage",
    ["ls.VMHitFailedEntry"] = "miss",
    ["ls.VMCombatNextRoundEntry"] = "round",
    ["ls.VMHitKilledDefenderEntry"] = "killed",
    ["ls.VMEntityDiedEntry"] = "killed",
    ["ls.VMStatusAddedEntry"] = "statusAdded",
    ["ls.VMStatusRemovedEntry"] = "statusRemoved",
    ["ls.VMAutomaticDialogEntry"] = "speech", -- a bark: "[1]: [2]" ("Tav: Pues ya estaría.")
}

-- Lines that must not wait behind others: a death (verified types above); downed and dying are a
-- hypothesis from the naming pattern: check the log when a party member goes down.
local function isUrgent(entryType)
    return KINDS[entryType] == "killed" or entryType:find("Downed") ~= nil or entryType:find("Dying") ~= nil
end

-- The template rendered with parameter `skip` left out (a subject said elsewhere).
local function renderWithout(ctx, skip)
    local template = tostring(Vm.Get(ctx, "Text") or "")
    local params = Vm.List(ctx, "Params")
    local s = template:gsub("%[(%d+)%]", function(n)
        n = tonumber(n)
        local p = params[n]
        if n == skip or not p then return "" end
        return tostring(Vm.Get(p, "Text") or "")
    end)
    return Text.Clean(s)
end

-- One entry as data: { text, depth, kind ("action", "damage", "miss", "killed", "statusAdded",
-- "statusRemoved", "round", "other"), status (the status name of status lines),
-- type (entry VM type), urgent, actor, actorRelation, target (actions), spell, damage, speaker
-- and said (barks: who, and the line alone), subject
-- (who a result line is about: the damaged, the missed, the dead, or the character a line starts
-- with), phrase (the line without its subject and final stop: "ha fallado una tirada de
-- salvación contra Llama sagrada", "ha recibido el estado «Durmiendo»") }.
local function describe(g)
    local ctx = Vm.Get(g, "CtxTransText")
    local first = Vm.List(g, "Entries")[1]
    local entryType = first and tostring(first.Type) or ""
    local e = {
        text = render(ctx), depth = Vm.Get(g, "ChildDepth") or 0,
        type = entryType, kind = KINDS[entryType] or "other", urgent = isUrgent(entryType),
    }
    local chars = {}
    for i, p in ipairs(Vm.List(ctx, "Params")) do
        local t, text = Vm.Enum(p, "Type"), tostring(Vm.Get(p, "Text") or "")
        if t == "Character" then
            chars[#chars + 1] = { index = i, name = text, relation = Vm.Enum(p, "RelationType") }
        elseif t == "Spell" or t == "Interrupt" then
            e.spell = e.spell or text -- a reaction names its Interrupt ("Ataque temerario")
        elseif t == "Damage" then
            e.damage = text
        elseif t == "Status" then
            e.status = text
        end
    end
    local firstChar, lastChar = chars[1], chars[#chars]
    if e.kind == "speech" then
        e.speaker = firstChar and firstChar.name
        for _, p in ipairs(Vm.List(ctx, "Params")) do
            if Vm.Enum(p, "Type") ~= "Character" then e.said = Text.Clean(tostring(Vm.Get(p, "Text") or "")) end
        end
    elseif e.kind == "action" then
        e.actor, e.actorRelation = firstChar and firstChar.name, firstChar and firstChar.relation
        e.target = chars[2] and chars[2].name
    elseif e.kind == "miss" then
        e.actor, e.subject = firstChar and firstChar.name, chars[2] and chars[2].name
    elseif e.kind == "damage" then
        -- The damaged is the reference just before the damage in the template, a character or a
        -- thing: "[2] ha recibido un impacto de [3]" (Pulgoso's bite on "Rejilla de celda
        -- ruidosa" was said as "Pulgoso: Mordisco, 4 de daño" when the last character was
        -- taken), "[1] ha impactado a [2] e inflige [3]" (a thrown handaxe: [1] is the axe,
        -- 2026-09-25).
        local params = Vm.List(ctx, "Params")
        local prev, subjectIndex = nil, nil
        for n in tostring(Vm.Get(ctx, "Text") or ""):gmatch("%[(%d+)%]") do
            n = tonumber(n)
            local p = params[n]
            if p and Vm.Enum(p, "Type") == "Damage" then
                subjectIndex = prev
                break
            end
            prev = n
        end
        local p = subjectIndex and params[subjectIndex]
        e.subject = (p and tostring(Vm.Get(p, "Text") or "")) or (lastChar and lastChar.name)
    elseif e.kind == "killed" then
        e.subject = lastChar and lastChar.name -- "[1] ha matado a [2]"
    elseif e.kind ~= "speech" and firstChar and tostring(Vm.Get(ctx, "Text") or ""):find("^%[" .. firstChar.index .. "%]") then
        -- Only a line that starts with the character loses it ("[1] ha recibido el estado..."):
        -- "Han curado a [1] un total de 7 puntos de golpe" would lose its grammar (gate fight).
        e.subject = firstChar.name
        -- Some templates end in ".." ("[1] [2] [3].."): drop every final stop.
        e.phrase = (renderWithout(ctx, firstChar.index):gsub("[%.。%s]+$", ""))
    end
    return e
end

-- Entries from index `from` on (describe() tables), in log order.
function CombatLog.Entries(from)
    local out = {}
    local list = groups()
    for i = from or 1, #list do out[#out + 1] = describe(list[i]) end
    return out
end

return CombatLog
