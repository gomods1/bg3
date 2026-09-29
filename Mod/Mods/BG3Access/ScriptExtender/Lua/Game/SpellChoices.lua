-- Spell choices (ls.VMSpellSelector): the spells or cantrips a level up (and character creation)
-- asks for. Facts (verified 2026-09-24, Gale wizard 1 -> 2, widget CharacterLevelUp):
--   selector: Title / Description (handles), IsCantrips, IsComplete, AddedCount (chosen),
--     Additions[] (one entry per slot, Spell empty until chosen: its count is how many to choose),
--     Available[] (ls.VMSpellReference: Spell { Name handle, Level, SpellSchool }, Selected,
--     NotAvailable = already known: the game shows no button for those).
--   The game's spell panel for a selector opens when its tab (a ListBoxItem whose DataContext is
--     the selector, under the level-up tabs) is selected: its template then fills the widget's
--     gameplaySubPanel. Setting the item's IsSelected does what a click on the tab does.
--   Choosing: the panel's buttons SelectAvailableSpell / DeselectAddedSpell run the DC's
--     SelectSpell / DeselectSpell with a MultiBinding [selector, spell] that Lua cannot build, so
--     they are pressed with a verified click (Activate.ClickGridItem).
local Vm = Ext.Require("Game/Vm.lua")
local Ui = Ext.Require("Game/Ui.lua")
local Loca = Ext.Require("Game/Loca.lua")
local Spells = Ext.Require("Game/Spells.lua")
local Activate = Ext.Require("Game/Activate.lua")
local Timer = Ext.Require("Core/Timer.lua")

local SpellChoices = {}

local SELECT_BUTTON = "SelectAvailableSpell"
local DESELECT_BUTTON = "DeselectAddedSpell"
local PANEL_OPEN_MS = 400 -- the panel's buttons exist a few frames after the tab is selected
local RESULT_POLL_MS = 100
local RESULT_WAIT_MS = 1500 -- the bridge clicks ~220 ms after the request; the VM follows

-- A source is { widget = name, selectors = function() -> { selector VMs } (valid this tick),
-- ready = optional function(onReady(ok), onWait()) that waits until the widget takes clicks,
-- and, for panels that are not opened by a tab (a feat's spells): isOpen(i), open(i, onDone(ok)),
-- selectButton / deselectButton (the buttons' x:Names in that panel) }.

local function spellOf(ref)
    local sp = Vm.Get(ref, "Spell")
    local name = sp and Vm.Get(sp, "Name")
    if not name or name == "" then return nil end
    return sp, tostring(name)
end

-- { { title, description, cantrips, max, chosen, complete, spells = { { key, name, level, title,
--   id, selected } } } }: the spells the player can pick (already known ones left out, as the game
-- does). key identifies a spell within its selector (its name handle).
function SpellChoices.Read(source)
    local out = {}
    for _, s in ipairs(source.selectors()) do
        local c = {
            title = Vm.Text(s, "Title"),
            description = Vm.Text(s, "Description"),
            cantrips = Vm.Get(s, "IsCantrips") == true,
            max = #Vm.List(s, "Additions"),
            chosen = Vm.Get(s, "AddedCount") or 0,
            complete = Vm.Get(s, "IsComplete") == true,
            spells = {},
        }
        for _, ref in ipairs(Vm.List(s, "Available")) do
            local sp, key = spellOf(ref)
            if sp and Vm.Get(ref, "NotAvailable") ~= true then
                local level = Vm.Get(sp, "Level")
                c.spells[#c.spells + 1] = {
                    key = key,
                    name = Loca.Get(key) or "?",
                    level = level,
                    title = Spells.Title(Vm.Enum(sp, "SpellSchool"), level),
                    id = Spells.IdByName(key, level),
                    selected = Vm.Get(ref, "Selected") == true,
                }
            end
        end
        out[#out + 1] = c
    end
    return out
end

local function selectorAt(source, i)
    return source.selectors()[i]
end

-- The tab item (ListBoxItem) of selector i, or nil.
local function tabOf(source, i)
    local s = selectorAt(source, i)
    local w = Ui.FindWidget(source.widget)
    if not (s and w) then return nil end
    local found = nil
    local function walk(el, depth)
        if found or depth > 70 then return end
        if tostring(el.Type) == "ListBoxItem" and Vm.Same(Vm.Get(el, "DataContext"), s) then
            found = el
            return
        end
        for _, k in ipairs(Ui.Kids(el)) do walk(k, depth + 1) end
    end
    walk(w, 0)
    return found
end

function SpellChoices.IsOpen(source, i)
    if source.isOpen then return source.isOpen(i) end
    local s = selectorAt(source, i)
    local panel = Ui.FindElement(source.widget, "gameplaySubPanel")
    return Vm.Same(Vm.Get(panel, "DataContext"), s)
end

-- Opens the game's panel for selector i (as a click on its tab). onDone(ok) once its buttons exist.
function SpellChoices.Open(source, i, onDone)
    onDone = onDone or function() end
    if SpellChoices.IsOpen(source, i) then
        onDone(true)
        return
    end
    if source.open then
        source.open(i, function(ok)
            if not ok then onDone(false) return end
            Timer.After(PANEL_OPEN_MS, function() onDone(SpellChoices.IsOpen(source, i)) end)
        end)
        return
    end
    local tab = tabOf(source, i)
    if not tab then
        onDone(false)
        return
    end
    tab:SetProperty("IsSelected", true)
    Timer.After(PANEL_OPEN_MS, function() onDone(SpellChoices.IsOpen(source, i)) end)
end

local function buttons(source, name)
    local out = {}
    for _, el in ipairs(Ui.FindAllByName(Ui.FindWidget(source.widget), name)) do
        if Ui.IsShown(el) then out[#out + 1] = el end
    end
    return out
end

local function showsSpell(el, key)
    local _, k = spellOf(Ui.TemplateItem(el))
    return k == key
end

local function selectedByKey(source, i)
    local c = SpellChoices.Read(source)[i]
    local out = {}
    for _, sp in ipairs(c and c.spells or {}) do out[sp.key] = sp.selected end
    return out
end

-- After a click: onDone(true) once spell key changed state; (false, "reason_wrong_item") when
-- another spell changed instead; (false, "reason_no_effect") when nothing changed in time.
local function awaitResult(source, i, key, before, onDone)
    local started = Ext.Utils.MonotonicTime()
    local function poll()
        local now = selectedByKey(source, i)
        if now[key] ~= before[key] then
            onDone(true)
            return
        end
        for k, v in pairs(now) do
            if before[k] ~= v then
                onDone(false, "reason_wrong_item")
                return
            end
        end
        if Ext.Utils.MonotonicTime() - started > RESULT_WAIT_MS then
            onDone(false, "reason_no_effect")
            return
        end
        Timer.After(RESULT_POLL_MS, poll)
    end
    Timer.After(RESULT_POLL_MS, poll)
end

-- Chooses spell key of selector i, or takes it back when already chosen, by pressing the game's
-- button (verified click), and waits until the game shows the change. onDone(ok, reasonKey).
function SpellChoices.Toggle(source, i, key, onDone)
    onDone = onDone or function() end
    local c = SpellChoices.Read(source)[i]
    local spell = nil
    for _, sp in ipairs(c and c.spells or {}) do
        if sp.key == key then spell = sp end
    end
    if not spell then
        onDone(false, "reason_gone")
        return
    end
    if not spell.selected and c.chosen >= c.max then
        onDone(false, "reason_choices_full")
        return
    end
    local name = spell.selected and (source.deselectButton or DESELECT_BUTTON) or (source.selectButton or SELECT_BUTTON)
    SpellChoices.Open(source, i, function(open)
        if not open then
            onDone(false, "reason_gone")
            return
        end
        local before = selectedByKey(source, i)
        Activate.ClickGridItem(source.widget, {
            name = name,
            cells = function() return buttons(source, name) end,
            isTarget = function(el) return showsSpell(el, key) end,
        }, function(ok, reason)
            if not ok then
                onDone(false, reason)
                return
            end
            awaitResult(source, i, key, before, onDone)
        end)
    end)
end

return SpellChoices
