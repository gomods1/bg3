-- Skill check dice roll (template_rpg 15: "announce the setup, speak the rolled value, total and
-- outcome"; Game/ActiveRoll). On open: the check, the difficulty, the bonus and what the die must
-- show. Enter rolls and, after the result, goes on, through the game's own command for its Enter
-- binding (a real Enter did nothing, measured). The result is spoken as soon as the game has it
-- (before the dice animation ends). The mod menu offers the bonuses the party can add (Guidance...:
-- added with a verified click, Game/ActiveRoll), taking them back, and rolling again with
-- inspiration when the game allows it.
local Game = Ext.Require("Game/ActiveRoll.lua")
local Bridge = Ext.Require("Core/Bridge.lua")
local Speech = Ext.Require("Core/Speech.lua")
local Strings = Ext.Require("Core/Strings.lua")

local L = Strings.Get

local ActiveRoll = {}
ActiveRoll.__index = ActiveRoll
ActiveRoll.Widgets = { Game.Widget }

function ActiveRoll.New(widget)
    return setmetatable({ widget = widget.name, state = nil, spokenResult = false }, ActiveRoll)
end

local function signed(n)
    n = n or 0
    return n >= 0 and L("plus_number", { n = n }) or L("minus_number", { n = -n })
end

local function boostNames(boosts)
    local names = {}
    for _, b in ipairs(boosts) do names[#names + 1] = L("roll_boost_from", { name = b.name, owner = b.owner, dice = b.dice or "?" }) end
    return Strings.List(names)
end

local function bonusText(r)
    return r.bonusMin == r.bonusMax and signed(r.bonusMin)
        or L("bonus_range", { min = signed(r.bonusMin), max = signed(r.bonusMax) })
end

-- What the die must show. With dice in the bonus (Guidance's 1d4) it is a range: the game's
-- TargetNumber stays at the fixed bonus's number (13 for DC 15 with +2, also after Guidance made
-- the bonus +3 to +6; Blighted Village gate, 2026-09-24), so the range is worked out here.
-- A natural 1 always fails and a natural 20 always succeeds, whatever the numbers (the game's
-- TargetNumber said 1 for DC 2 with +1, Trinzas in the sanctum, 2026-09-24).
local function needOne(n)
    if n <= 2 then return L("roll_need_not_one") end
    if n >= 20 then return L("roll_need_twenty") end
    return L("roll_need", { n = n })
end

local function needText(r)
    if r.difficulty and r.bonusMin and r.bonusMax and r.bonusMin ~= r.bonusMax then
        local lo = math.max(2, math.min(20, r.difficulty - r.bonusMax))
        local hi = math.max(2, math.min(20, r.difficulty - r.bonusMin))
        if lo == hi then return needOne(lo) end
        return L("roll_need_range", { min = lo, max = hi })
    end
    return r.need and needOne(r.need)
end

local function setup(r)
    local bonus = bonusText(r)
    local boosts = r.state == "WaitForStart" and Game.Boosts() or {}
    return Strings.Sentences({
        L("roll_check", { skill = r.skill or "?" }),
        L("roll_difficulty", { n = r.difficulty or 0 }),
        L("roll_bonus", { bonus = bonus }),
        needText(r),
        r.advantage == "Advantage" and L("roll_with_advantage"),
        r.advantage == "Disadvantage" and L("roll_with_disadvantage"),
        r.inspiration > 0 and L("roll_inspiration", { n = r.inspiration }),
        #boosts > 0 and L("roll_boosts", { names = boostNames(boosts) }),
    })
end

local function result(r)
    local boosts = {}
    for _, b in ipairs(Game.AddedBoosts()) do
        if b.rolled then boosts[#boosts + 1] = L("roll_boost_rolled", { name = b.name, n = b.rolled }) end
    end
    return Strings.Sentences({
        L("roll_rolled", { n = r.rolled or 0 }),
        r.advantage and r.rolled2 and r.rolled2 > 0 and L("roll_other_die", { n = r.rolled2 }),
        #boosts > 0 and Strings.List(boosts),
        L("roll_total_bonus", { bonus = signed((r.result or 0) - (r.rolled or 0)) }),
        L("roll_total", { n = r.result or 0 }),
        L(r.success and "roll_success" or "roll_failure"),
    })
end

function ActiveRoll:Open()
    local r = Game.Read()
    if not r then return end
    self.state = r.state
    Speech.Say(Strings.Sentences({ setup(r), L("roll_enter") }))
end

-- The result appears once the dice have settled: the game marks the roll finished.
function ActiveRoll:Tick()
    local r = Game.Read()
    if not r then return end
    if self.nextWhenReady and r.state == "ResultReady" then
        self.nextWhenReady = false
        Game.Next()
    end
    if r.state ~= self.state then
        Bridge.Log("active roll state: " .. tostring(self.state) .. " -> " .. tostring(r.state))
        self.state = r.state
    end
    if r.finished and not self.spokenResult then
        self.spokenResult = true
        local parts = { result(r) }
        if not r.success and Game.CanRollAgain() then parts[#parts + 1] = L("roll_again_hint") end
        parts[#parts + 1] = L("roll_continue")
        Speech.Event(Strings.Sentences(parts), "dialogue")
    elseif not r.finished then
        self.spokenResult = false -- rolled again
    end
end

function ActiveRoll:ReadAll()
    local r = Game.Read()
    if not r then return end
    Speech.Say(r.finished and result(r) or setup(r), { interrupt = true })
end

function ActiveRoll:Help()
    return { L("help_roll") }
end

function ActiveRoll:Commands()
    local out = {}
    local r = Game.Read()
    if r and r.state == "WaitForStart" then
        for _, b in ipairs(Game.Boosts()) do
            out[#out + 1] = {
                label = L("roll_add_boost", { name = b.name, owner = b.owner, dice = b.dice or "?" }),
                run = function()
                    Speech.Say(L("roll_adding", { name = b.name }), { interrupt = true })
                    Game.AddBoost(b.key, function(ok, reason)
                        local now = Game.Read()
                        if ok and now then
                            Speech.Say(Strings.Sentences({ L("roll_boost_added", { name = b.name, bonus = bonusText(now) }), needText(now) }), { interrupt = true })
                        else
                            Speech.Say(L("could_not_activate", { label = b.name, reason = L(reason or "reason_no_effect") }), { interrupt = true })
                        end
                    end)
                end,
            }
        end
        for _, b in ipairs(Game.AddedBoosts()) do
            out[#out + 1] = {
                label = L("roll_remove_boost", { name = b.name }),
                run = function()
                    local ok = Game.RemoveBoost(b.index)
                    Speech.Say(ok and L("roll_boost_removed", { name = b.name }) or L("not_available_here"), { interrupt = true })
                end,
            }
        end
    end
    if Game.CanRollAgain() then
        out[#out + 1] = { label = L("roll_again"), run = function() Game.RollAgain() end }
    end
    return out
end

local NEXT_KEYS = { RETURN = true, KP_ENTER = true, SPACE = true }

function ActiveRoll:OnKey(combo)
    if NEXT_KEYS[combo] then
        -- While the dice still roll the game ignores the command (Enter right after the result
        -- was spoken did nothing: the total is known before the animation ends, Trinzas' check,
        -- 2026-09-24): it is sent once the roll is ready.
        local r = Game.Read()
        if r and r.state == "StartRoll" then
            self.nextWhenReady = true
            return true
        end
        if not Game.Next() then Speech.Say(L("not_available_here"), { interrupt = true }) end
        return true
    end
    return false -- Escape and the rest are the game's
end

return ActiveRoll
