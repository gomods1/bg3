-- Spell book (the game's spell book panel, key K) of the selected character (client). Facts
-- (verified 2026-09-24, Gale wizard 2):
--   PlayerCharacterProperties.SpellBooks[]: SpellBookType (Base, Tadpole, Class), Class (Class
--   books only: ClassDisplayName handle, MustPrepareSpells, IDString "Wizard"), PreparedSpellsStat (Value / Max: 5 of 5; -1 when the book has none),
--   ActionGroups[] (by spell level) with Actions[] (ls.VMCharacterAction: Name handle,
--   PrototypeID = spell stat id, SpellSlotLevel, NeedsActivation = must be prepared, Activated =
--   prepared), AlwaysPreparedActions[].
--   Preparing / unpreparing: any gui DC's ToggleCharacterAction(action) (the spell book's cells
--   use it with {Binding}: one plain parameter). Gale's Grease went 5 of 5 -> 4 of 5.
local Vm = Ext.Require("Game/Vm.lua")
local Player = Ext.Require("Game/Player.lua")
local Spells = Ext.Require("Game/Spells.lua")

local Spellbook = {}

local function classBooks()
    local out = {}
    for _, b in ipairs(Vm.List(Vm.Get(Player.SelectedCharacter(), "PlayerCharacterProperties"), "SpellBooks")) do
        if Vm.Enum(b, "SpellBookType") == "Class" then out[#out + 1] = b end
    end
    return out
end

local function actionsOf(book)
    local out = {}
    for _, g in ipairs(Vm.List(book, "ActionGroups")) do
        for _, a in ipairs(Vm.List(g, "Actions")) do out[#out + 1] = a end
    end
    return out
end

local function always(book)
    local out = {}
    for _, a in ipairs(Vm.List(book, "AlwaysPreparedActions")) do
        local id = Vm.Get(a, "PrototypeID")
        if id then out[tostring(id)] = true end
    end
    return out
end

-- The selected character's class spell books: { { class, prepared, max, spells = { { id, name,
-- level, title, state = "prepared" | "unprepared" | "always" | "known" (cantrips and other
-- spells that need no preparing) } } } }, spells by level. Empty for classes without spells.
function Spellbook.Read()
    local out = {}
    for _, book in ipairs(classBooks()) do
        local stat = Vm.Get(book, "PreparedSpellsStat")
        local entry = {
            class = Vm.Text(Vm.Get(book, "Class"), "ClassDisplayName"),
            prepared = Vm.Get(stat, "Value"), max = Vm.Get(stat, "Max"),
            spells = {},
        }
        local alwaysIds = always(book)
        for _, a in ipairs(actionsOf(book)) do
            local id = tostring(Vm.Get(a, "PrototypeID") or "")
            local level = Vm.Get(a, "SpellSlotLevel") or 0
            local state = "known"
            if alwaysIds[id] then
                state = "always"
            elseif Vm.Get(a, "NeedsActivation") == true then
                state = Vm.Get(a, "Activated") == true and "prepared" or "unprepared"
            end
            entry.spells[#entry.spells + 1] = {
                id = id, name = Vm.Text(a, "Name") or "?", level = level,
                title = Spells.Title(Vm.Enum(a, "SpellSchool"), level), state = state,
            }
        end
        if #entry.spells > 0 then out[#out + 1] = entry end
    end
    return out
end

-- Prepares or unprepares spell id of class book b. Returns ok (applied on a later frame; the
-- game refuses in combat and when the book is full).
function Spellbook.Toggle(b, id)
    local book = classBooks()[b]
    for _, a in ipairs(actionsOf(book)) do
        if tostring(Vm.Get(a, "PrototypeID") or "") == id and Vm.Get(a, "NeedsActivation") == true then
            return Vm.Run(Vm.WidgetDc("HotBar"), "ToggleCharacterAction", a)
        end
    end
    return false
end

return Spellbook
