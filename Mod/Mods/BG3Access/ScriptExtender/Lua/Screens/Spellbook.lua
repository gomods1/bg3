-- Spell book (mod menu): the selected character's class spells (Game/Spellbook), by level, with
-- their state ("Proyectil mágico, Conjuro de evocación niv. 1, not prepared"). Enter prepares or
-- unprepares a spell that needs preparing (the game allows it outside combat, up to the book's
-- maximum); Ctrl+D describes a spell. With several classes, each class opens its own list.
local Game = Ext.Require("Game/Spellbook.lua")
local Speech = Ext.Require("Core/Speech.lua")
local Strings = Ext.Require("Core/Strings.lua")
local ListScreen = Ext.Require("Screens/ListScreen.lua")
local Controls = Ext.Require("Screens/Controls.lua")
local SpellWords = Ext.Require("Screens/SpellWords.lua")

local L = Strings.Get

local Spellbook = ListScreen.Extend()

function Spellbook.New(onClose)
    local self = setmetatable(ListScreen.New("(spellbook)", L("screen_spellbook")), Spellbook)
    self.onClose = onClose
    return self
end

local function bookTitle(book)
    if book.max and book.max >= 0 then
        return L("spellbook_class", { class = book.class or "?", prepared = book.prepared or 0, max = book.max })
    end
    return book.class or "?"
end

local function spellState(b, id)
    local book = Game.Read()[b]
    for _, sp in ipairs(book and book.spells or {}) do
        if sp.id == id then return sp.state end
    end
    return nil
end

local function spellControl(b, sp)
    local id = sp.id
    local function describe()
        local state = spellState(b, id) or sp.state
        return SpellWords.Line(sp, state ~= "known" and L("spell_state_" .. state))
    end
    return Controls.Item({
        kind = sp.state == "known" and "text" or "button",
        describe = describe,
        details = function() return SpellWords.Details(id) end,
        activate = function()
            local before = spellState(b, id)
            if before == "known" or before == "always" then
                Speech.Say(describe(), { interrupt = true })
                return
            end
            local function result()
                local now = Game.Read()[b]
                local state = spellState(b, id)
                return state and now and Strings.List({ L("spell_state_" .. state), bookTitle(now) })
            end
            local book = Game.Read()[b]
            if before == "unprepared" and book and book.max and book.max >= 0 and (book.prepared or 0) >= book.max then
                Speech.Say(L("spellbook_full", { max = book.max }), { interrupt = true })
                return
            end
            local was = result()
            if not Game.Toggle(b, id) then
                Speech.Say(L("spellbook_cannot_change"), { interrupt = true })
                return
            end
            Controls.SayWhenChanged(result, was)
        end,
    })
end

local function spellsOf(b)
    local book = Game.Read()[b]
    local out = {}
    for _, sp in ipairs(book and book.spells or {}) do
        -- one section per spell level (NAVIGATION.md: Tab between them)
        local c = spellControl(b, sp)
        c.section = (sp.level or 0) == 0 and L("spell_choice_cantrips") or L("spells_of_level", { level = sp.level })
        out[#out + 1] = c
    end
    return out
end

function Spellbook:Build()
    local books = Game.Read()
    if #books == 1 then
        self.title = bookTitle(books[1])
        return spellsOf(1)
    end
    local out = {}
    for b, book in ipairs(books) do
        out[#out + 1] = Controls.Item({
            kind = "button",
            describe = function()
                local now = Game.Read()[b]
                return now and bookTitle(now) or L("option_gone")
            end,
            activate = function() self:Push(bookTitle(book), function() return spellsOf(b) end) end,
        })
    end
    if #out == 0 then out[1] = Controls.Text(L("spellbook_none")) end
    return out
end

function Spellbook:Help()
    local lines = ListScreen.Help(self)
    lines[#lines + 1] = L("help_spellbook")
    return lines
end

return Spellbook
