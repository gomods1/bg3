-- The combat log in compact form (template_rpg: "Goblin archer: hits Shadowheart for 6, misses
-- you"). A unit is one action and its results (Game/CombatLog entries: the depth-0 line and the
-- depth-1 lines under it); results are said per target, in the order the log names them:
--   "Warryn: Flecha de ácido. Gale: 4 de daño de ácido, ha fallado una tirada de salvación contra
--    Flecha de ácido. Tav: missed."
-- Deaths come first, once each. Other lines about a character are grouped under that character
-- with the game's own phrase ("ha recibido el estado «Durmiendo»"); anything else is said as the
-- game wrote it.
local Strings = Ext.Require("Core/Strings.lua")

local L = Strings.Get

local LogWords = {}

local function head(h, withActor)
    if h.kind ~= "action" or not h.spell then return h.text end
    if withActor and h.actor then
        return L(h.target and "log_action_target" or "log_action", { actor = h.actor, spell = h.spell, target = h.target })
    end
    return L(h.target and "log_again_target" or "log_again", { spell = h.spell, target = h.target })
end

-- unit = { head = entry?, results = { entries } } (no head: results whose action line was said
-- before); withActor: say who acts (the first unit of a group). Returns the sentences to speak.
function LogWords.Unit(unit, withActor)
    local parts, others = {}, {}
    -- Deaths first, once per character (the game logs a kill twice: who killed, then the death).
    local dead = {}
    for _, r in ipairs(unit.results) do
        if r.urgent and not (r.subject and dead[r.subject]) then
            parts[#parts + 1] = r.text
            if r.subject then dead[r.subject] = true end
        end
    end
    local headIndex = nil
    if unit.head then
        parts[#parts + 1] = head(unit.head, withActor)
        headIndex = #parts
    end
    local order, bySubject = {}, {}
    local function add(subject, text)
        if not bySubject[subject] then
            bySubject[subject] = {}
            order[#order + 1] = subject
        end
        local list = bySubject[subject]
        list[#list + 1] = text
    end
    for _, r in ipairs(unit.results) do
        local text = (r.kind == "damage" and r.damage) or (r.kind == "miss" and L("log_missed")) or r.phrase
        if r.urgent then
            -- said first
        elseif r.subject and text then
            add(r.subject, text)
        else
            others[#others + 1] = r.text
        end
    end
    local actor = unit.head and unit.head.actor
    -- Characters with the same results are said together (Grease: "Corazón Sombrío, Tav, Lae'zel:
    -- ha fallado una tirada de salvación contra Grasa, ha recibido el estado «Derribado»").
    local groups, byResults = {}, {}
    for _, subject in ipairs(order) do
        local results = Strings.List(bySubject[subject])
        local g = byResults[results]
        if not g then
            g = { subjects = {}, results = results }
            groups[#groups + 1] = g
            byResults[results] = g
        end
        g.subjects[#g.subjects + 1] = subject
    end
    for _, g in ipairs(groups) do
        -- About the actor itself (a buff it cast on itself, a heal it gave: the game's phrase
        -- starts with the verb, "ha curado a Pájaro exhausto..."): joined to the action line, where
        -- the actor was named.
        local onlyActor = #g.subjects == 1 and g.subjects[1] == actor
        if onlyActor and headIndex then
            parts[headIndex] = L("log_action_results", { action = parts[headIndex], results = g.results })
        else
            parts[#parts + 1] = L("log_target", { target = Strings.List(g.subjects), results = g.results })
        end
    end
    for _, text in ipairs(others) do parts[#parts + 1] = text end
    return Strings.Sentences(parts)
end

-- Several phrases the game wrote about one character, said once: the words they start with
-- (or end with) once, the rest as a list ("ha recogido 1 Olla, 1 Provisiones"). Phrases that share
-- fewer than MIN_SHARED words at either end (one shared word is often only an auxiliary: "ha
-- recogido 1 Olla, perdido el estado..."), and languages written without spaces, are listed whole.
local MIN_SHARED = 2
local function words(text)
    local out = {}
    for w in text:gmatch("%S+") do out[#out + 1] = w end
    return out
end

local function joinRange(list, from, to)
    return table.concat(list, " ", from, to)
end

local function mergePhrases(phrases)
    if #phrases == 1 then return phrases[1] end
    local split, shortest = {}, math.huge
    for i, p in ipairs(phrases) do
        split[i] = words(p)
        shortest = math.min(shortest, #split[i])
    end
    local function common(at)
        local k = 0
        while k < shortest - 1 do
            local w = at(split[1], k)
            for i = 2, #split do
                if at(split[i], k) ~= w then return k end
            end
            k = k + 1
        end
        return k
    end
    local prefix = common(function(ws, k) return ws[k + 1] end)
    if prefix >= MIN_SHARED then
        local tails = {}
        for i, ws in ipairs(split) do tails[i] = joinRange(ws, prefix + 1, #ws) end
        return joinRange(split[1], 1, prefix) .. " " .. Strings.List(tails)
    end
    local suffix = common(function(ws, k) return ws[#ws - k] end)
    if suffix >= MIN_SHARED then
        local heads = {}
        for i, ws in ipairs(split) do heads[i] = joinRange(ws, 1, #ws - suffix) end
        return Strings.List(heads) .. " " .. joinRange(split[1], #split[1] - suffix + 1, #split[1])
    end
    return Strings.List(phrases)
end

-- Units said at once (the party's actions, lines about one character): lines with the same
-- phrase about different characters become one ("Wyll, Corazón Sombrío, Aradin: ha recibido el
-- estado «Alentado»", seven lines in the gate fight), and several lines about one character too
-- ("Tav: ha recogido 1 Olla, 1 Provisiones").
function LogWords.Many(units)
    local parts, byPhrase, bySubject = {}, {}, {}
    for _, u in ipairs(units) do
        local h = u.head
        if h and h.kind ~= "action" and h.subject and h.phrase and #u.results == 0 then
            local g = byPhrase[h.phrase]
            if g then
                g.subjects[#g.subjects + 1] = h.subject
            else
                g = { subjects = { h.subject }, phrases = { h.phrase } }
                byPhrase[h.phrase] = g
                parts[#parts + 1] = g
            end
        else
            parts[#parts + 1] = LogWords.Unit(u, true)
        end
    end
    -- Then one character's different lines go together, where the first of them stands.
    local merged = {}
    for _, p in ipairs(parts) do
        local one = type(p) == "table" and #p.subjects == 1 and p.subjects[1]
        local first = one and bySubject[one]
        if first then
            first.phrases[#first.phrases + 1] = p.phrases[1]
        else
            if one then bySubject[one] = p end
            merged[#merged + 1] = p
        end
    end
    for i, p in ipairs(merged) do
        if type(p) == "table" then
            merged[i] = L("log_target", { target = Strings.List(p.subjects), results = mergePhrases(p.phrases) })
        end
    end
    return Strings.Sentences(merged)
end

-- Several units of one actor as one announcement.
function LogWords.Group(units)
    local parts = {}
    for i, u in ipairs(units) do parts[#parts + 1] = LogWords.Unit(u, i == 1) end
    return Strings.Sentences(parts)
end

return LogWords
