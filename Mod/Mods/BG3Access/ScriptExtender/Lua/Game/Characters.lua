-- Character view models (ls.Character, client) as plain snapshots. Facts (verified 2026-09-24):
-- Name (handle), EntityUUID, IsCurrentTurn, PlayerRelation (Player/Enemy/...), CharacterType
-- (Avatar/Companion/None), Stats.Health (ls.VMRangeStat: Value, Max), Stats.ActionResources[]
-- (ls.VMActionResource: Name handle, TypeId ActionPoint/BonusActionPoint/ReactionActionPoint/
-- Rage/..., Value, MaxValue, IsHidden), Stats.MovementResource (Value/MaxValue in meters),
-- StatusEffects[] (gui status VM: Name handle, StatusId RAGE, Duration 10 = turns left,
-- DurationType Timer; verified with Rage), Stats.SpellSlots[] (TypeId SpellSlot, Level 1..,
-- Value, MaxValue; 8 entries for Shadowheart, the unused levels with MaxValue 0; verified in the
-- helm fight).
local Vm = Ext.Require("Game/Vm.lua")
local Loca = Ext.Require("Game/Loca.lua")

local Characters = {}

-- { name, uuid, relation, type, currentTurn, hp, maxHp, movement, maxMovement,
--   resources = { { id, name, value, max } }, slots = { { level, value, max } },
--   statuses = { { id, name, turns? } } } or nil.
function Characters.Snapshot(vm)
    if not vm then return nil end
    local stats = Vm.Get(vm, "Stats")
    local hp = Vm.Get(stats, "Health")
    local move = Vm.Get(stats, "MovementResource")
    local s = {
        name = Vm.Text(vm, "Name"),
        uuid = Vm.Get(vm, "EntityUUID"),
        relation = Vm.Enum(vm, "PlayerRelation"),
        type = Vm.Enum(vm, "CharacterType"),
        currentTurn = Vm.Get(vm, "IsCurrentTurn") == true,
        hp = Vm.Get(hp, "Value"),
        maxHp = Vm.Get(hp, "Max"),
        movement = Vm.Get(move, "Value"),
        maxMovement = Vm.Get(move, "MaxValue"),
        resources = {},
        statuses = {},
        slots = {},
    }
    for _, sl in ipairs(Vm.List(stats, "SpellSlots")) do
        local max = Vm.Get(sl, "MaxValue") or 0
        if max > 0 and Vm.Get(sl, "IsHidden") ~= true then
            s.slots[#s.slots + 1] = { level = Vm.Get(sl, "Level"), value = Vm.Get(sl, "Value"), max = max }
        end
    end
    for _, st in ipairs(Vm.List(vm, "StatusEffects")) do
        local turns = tonumber(Vm.Get(st, "Duration"))
        s.statuses[#s.statuses + 1] = {
            id = Vm.Get(st, "StatusId"),
            name = Vm.Text(st, "Name"),
            turns = (turns and turns > 0) and turns or nil,
        }
    end
    for _, r in ipairs(Vm.List(stats, "ActionResources")) do
        if Vm.Get(r, "IsHidden") ~= true then
            s.resources[#s.resources + 1] = {
                id = Vm.Enum(r, "TypeId"),
                name = Vm.Text(r, "Name"),
                value = Vm.Get(r, "Value"),
                max = Vm.Get(r, "MaxValue"),
            }
        end
    end
    return s
end

-- The sheet of character view model vm (the character panel's, or the Examine window's target;
-- verified 2026-09-25 on Gale: Stats.Race.DisplayName "Humano", Stats.Background "Erudito",
-- ClassList[] ClassDisplayName / SubclassDisplayName "Mago" / "Evocación",
-- PlayerCharacterProperties.ApprovalRatings[] { Character (VM: Tav), Rating 12, Description "La
-- relación es neutral..." }): { name, level?, xp, xpNext, levelUp, race, background, hp, hpMax,
-- ac, classes = { { name, subclass? } }, abilities = { { name, value, modifier, save } },
-- traits = { text }, approvals = { { name, rating, description } } } or nil. Class and level are
-- left out where the game hides them (HasVisibleClassAndLevel false).
function Characters.Sheet(vm)
    if not vm then return nil end
    local stats = Vm.Get(vm, "Stats")
    local level = Vm.Get(stats, "Level")
    local health = Vm.Get(stats, "Health")
    local visible = Vm.Get(vm, "HasVisibleClassAndLevel") ~= false
    local out = {
        name = Vm.Text(vm, "Name"),
        level = visible and Vm.Get(level, "Value") or nil,
        xp = Vm.Get(Vm.Get(stats, "Experience"), "Value"),
        xpNext = Vm.Get(level, "XPForNextLevel"),
        levelUp = Vm.Get(level, "LevelUpAvailable") == true,
        race = Vm.Text(Vm.Get(stats, "Race"), "DisplayName"),
        background = Vm.Text(stats, "Background"),
        hp = Vm.Get(health, "Value"),
        hpMax = Vm.Get(health, "Max"),
        ac = Vm.Get(Vm.Get(stats, "ArmorClass"), "Value"),
        classes = {}, abilities = {}, traits = {}, approvals = {},
    }
    for _, c in ipairs(visible and Vm.List(stats, "ClassList") or {}) do
        out.classes[#out.classes + 1] = { name = Vm.Text(c, "ClassDisplayName"), subclass = Vm.Text(c, "SubclassDisplayName") }
    end
    for _, a in ipairs(Vm.List(stats, "Abilities")) do
        local id = Vm.Enum(a, "Ability")
        out.abilities[#out.abilities + 1] = {
            name = Loca.Enum("AbilityDisplayName", id) or id,
            value = Vm.Get(a, "Value"),
            modifier = Vm.Get(a, "Modifier"),
            save = Vm.Get(a, "HasSavingThrowProficiency") == true,
        }
    end
    for _, p in ipairs(Vm.List(stats, "Passives")) do
        out.traits[#out.traits + 1] = Vm.Text(p, "Name")
    end
    for _, a in ipairs(Vm.List(Vm.Get(vm, "PlayerCharacterProperties"), "ApprovalRatings")) do
        out.approvals[#out.approvals + 1] = {
            name = Vm.Text(Vm.Get(a, "Character"), "Name"),
            rating = Vm.Get(a, "Rating"),
            description = Vm.Text(a, "Description"),
        }
    end
    return out
end

return Characters
