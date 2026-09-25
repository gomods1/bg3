-- Base for screens the mod presents as a vertical list of controls (Screens/Controls): the
-- navigation layer of template_rpg 10.4 for tier-C screens.
-- Keys: Up/Down move, Home/End jump, Enter/Space/keypad Enter activate, Left/Right change a value.
-- A letter jumps to the next item starting with it, in mod screens (onClose, or LetterJump set
-- by the screen class: the mod menu) and sub-lists only (Gale's 40 spells at level 3); on screens
-- that mirror the game's own, letters stay the game's (M closes the map, I the inventory).
--
-- Screen interface used by the router (every screen module implements it):
--   Module.Widgets / Module.DcTypes   what the module handles (see Screens/Router)
--   Module.New(widget, page)          widget = { name, dcType }, page = XAML index entry or nil
--   screen:Open()                     first announcement
--   screen:Tick()                     optional, ~10 times a second while in front
--   screen:OnKey(combo) -> handled
--   screen:ReadAll()                  read-screen key
--   screen:Help() -> { lines }        help key (screen part)
--
-- Subclasses implement self:Build() -> { controls }. It runs on Open and again from Tick while the
-- list is still empty (a widget's content often appears a few frames after the widget itself); the
-- summary is spoken once content appears, or after EMPTY_WAIT_MS with "nothing to read". Call
-- self:Refresh() when the content changes (tabs, pages).
--
-- Mod screens set self.onClose (Router.CloseModScreen): Escape at the top level closes them.
-- Sub-lists: self:Push(title, build, startIndex) opens a nested list (e.g. the races of character
-- creation); Escape or Backspace goes back to the parent list, at the item that opened it.
local Speech = Ext.Require("Core/Speech.lua")
local Strings = Ext.Require("Core/Strings.lua")
local Config = Ext.Require("Core/Config.lua")
local Log = Ext.Require("Core/Log.lua")
local Text = Ext.Require("Core/Text.lua")

local L = Strings.Get

local EMPTY_WAIT_MS = 3000

local ListScreen = {}
ListScreen.__index = ListScreen

function ListScreen.New(widgetName, title)
    return setmetatable({ widget = widgetName, title = title or widgetName, controls = {}, index = 0, levels = {} }, ListScreen)
end

-- Makes a subclass: local Foo = ListScreen.Extend(); function Foo.New(...) local self = ListScreen.New(...); return setmetatable(self, Foo) end
function ListScreen.Extend(base)
    local class = setmetatable({}, { __index = base or ListScreen })
    class.__index = class
    return class
end

function ListScreen:Build()
    return {}
end

-- Title of the list being shown (the screen's, or the open sub-list's).
function ListScreen:CurrentTitle()
    local top = self.levels[#self.levels]
    return top and top.title or self.title
end

-- Rebuilds the controls, keeping the cursor position when possible.
function ListScreen:Refresh()
    local top = self.levels[#self.levels]
    local ok, controls = pcall(top and top.build or self.Build, self)
    if not ok then
        Log.Error("build " .. tostring(self.widget) .. ": " .. tostring(controls))
        controls = {}
    end
    self.controls = controls
    self.index = math.min(self.index, #controls)
end

function ListScreen:Current()
    return self.controls[self.index]
end

function ListScreen:Count(kind)
    local n = 0
    for _, c in ipairs(self.controls) do
        if c.kind == kind then n = n + 1 end
    end
    return n
end

-- "Main menu. 8 buttons." / "Options, Audio. 16 items: 13 options, 2 buttons." / "Chest. 3 items."
-- The breakdown is only given when the list has options (values to change).
function ListScreen:Summary()
    local n = #self.controls
    -- Titles are game text and may end with a stop ("Encuentra una cura."): the summary adds its own.
    local title = Text.StripStop(self:CurrentTitle() or "")
    if n == 0 then return L("screen_empty", { title = title }) end
    local buttons, options = self:Count("button"), self:Count("option")
    if buttons == n then return L("screen_summary_one_kind", { title = title, what = L("count_buttons", { n = n }) }) end
    if options == n then return L("screen_summary_one_kind", { title = title, what = L("count_options", { n = n }) }) end
    if options == 0 then return L("screen_summary_one_kind", { title = title, what = L("count_items", { n = n }) }) end
    local parts = { L("count_options", { n = options }) }
    if buttons > 0 then parts[#parts + 1] = L("count_buttons", { n = buttons }) end
    return L("screen_summary", { title = title, count = n, parts = Strings.List(parts) })
end

function ListScreen:Announce()
    local parts = { self:Summary() }
    if Config.Get("speech.screenHints") and #self.controls > 0 then
        for _, line in ipairs(self:Help()) do parts[#parts + 1] = line end
    end
    Speech.Say(Strings.Sentences(parts))
end

function ListScreen:Open()
    self:Refresh()
    if #self.controls == 0 then
        self.emptySince = Ext.Timer.MonotonicTime()
        return
    end
    self:Announce()
end

function ListScreen:Tick()
    if not self.emptySince then return end
    self:Refresh()
    if #self.controls > 0 or Ext.Timer.MonotonicTime() - self.emptySince > EMPTY_WAIT_MS then
        self.emptySince = nil
        self:Announce()
    end
end

-- Opens a nested list built by build(self) -> { controls }, with the cursor on startIndex (or
-- before the first item).
-- onLeave: optional, called when the sub-list is left (Escape, Backspace or Pop).
function ListScreen:Push(title, build, startIndex, onLeave)
    self.levels[#self.levels + 1] = { title = title, build = build, parentIndex = self.index, onLeave = onLeave }
    self.index = 0
    self:Refresh()
    if startIndex and self.controls[startIndex] then
        self.index = startIndex
        Speech.Say(Strings.Sentences({ self:Summary(), self.controls[startIndex].Describe() }), { interrupt = true })
    else
        Speech.Say(self:Summary(), { interrupt = true })
    end
end

-- Back to the parent list, which is read (quiet: not read, e.g. when a game window took over);
-- returns false at the top level.
function ListScreen:Pop(quiet)
    local top = table.remove(self.levels)
    if not top then return false end
    if top.onLeave then top.onLeave() end
    self.index = top.parentIndex
    self:Refresh()
    if quiet then return true end
    local c = self:Current()
    Speech.Say(c and c.Describe() or self:Summary(), { interrupt = true })
    return true
end

function ListScreen:Speak(control)
    Speech.Say(control.Describe(), { interrupt = true })
end

function ListScreen:Move(delta)
    if #self.controls == 0 then self:Refresh() end
    local n = #self.controls
    if n == 0 then
        Speech.Say(L("screen_empty", { title = self:CurrentTitle() }), { interrupt = true })
        return
    end
    self.index = math.max(1, math.min(n, self.index + delta))
    self:Speak(self.controls[self.index])
end

function ListScreen:Jump(toLast)
    if #self.controls == 0 then return end
    self.index = toLast and #self.controls or 1
    self:Speak(self.controls[self.index])
end

function ListScreen:Activate()
    local c = self:Current()
    if not c then
        Speech.Say(L("nothing_selected"), { interrupt = true })
    elseif c.Activate then
        c.Activate()
    else
        self:Speak(c)
    end
end

-- Returns handled: false lets the key through to the game when the control has no value to change.
function ListScreen:Change(delta, fine)
    local c = self:Current()
    if not (c and c.Change) then return false end
    c.Change(delta, fine)
    return true
end

-- Details key: the current control's longer description.
function ListScreen:Details()
    local c = self:Current()
    local d = c and c.Details and c.Details()
    Speech.Say(d or L("no_details"), { interrupt = true })
end

function ListScreen:ReadAll()
    local parts = { self:CurrentTitle() }
    for _, c in ipairs(self.controls) do parts[#parts + 1] = c.Describe() end
    Speech.Say(Strings.Sentences(parts), { interrupt = true })
end

function ListScreen:Help()
    local lines = { L("help_list") }
    if self:Count("option") > 0 then lines[#lines + 1] = L("help_change") end
    if #self.levels > 0 then lines[#lines + 1] = L("help_back") end
    return lines
end

local ACTIVATE = { RETURN = true, SPACE = true, KP_ENTER = true }

-- Hands every key to a text entry (Screens/TextEntry) until it is confirmed or cancelled.
function ListScreen:BeginEntry(entry)
    self.entry = entry
    entry:Start()
end

-- Letters with accents compare as their base letter ("Á" as "A").
local BASE_LETTERS = { ["á"] = "a", ["é"] = "e", ["í"] = "i", ["ó"] = "o", ["ú"] = "u", ["ü"] = "u",
    ["Á"] = "a", ["É"] = "e", ["Í"] = "i", ["Ó"] = "o", ["Ú"] = "u", ["Ü"] = "u", ["à"] = "a", ["è"] = "e",
    ["ò"] = "o", ["À"] = "a", ["È"] = "e", ["Ò"] = "o", ["ç"] = "c", ["Ç"] = "c" }

local function firstLetter(text)
    local rest = tostring(text or ""):gsub("^[%s%p]+", "")
    -- One UTF-8 character (SE's Lua has no utf8 library).
    local first = rest:match("^[\0-\127]") or rest:match("^[\194-\244][\128-\191]*")
    if not first then return nil end
    return BASE_LETTERS[first] or first:lower()
end

-- Moves to the next control after the current one whose text starts with the letter of key (an
-- SDL key name, "P"), wrapping round; says so when there is none.
function ListScreen:JumpToLetter(key)
    local letter = key:lower()
    local n = #self.controls
    for step = 1, n do
        local i = (self.index + step - 1) % n + 1
        if firstLetter(self.controls[i].Describe()) == letter then
            self.index = i
            self:Speak(self.controls[i])
            return
        end
    end
    Speech.Say(L("no_item_with_letter", { letter = key }), { interrupt = true })
end

function ListScreen:OnKey(combo)
    if self.entry then
        local handled = self.entry:OnKey(combo)
        if self.entry.finished then self.entry = nil end
        return handled
    end
    if combo == "DOWN" then self:Move(1) return true end
    if combo == "UP" then self:Move(-1) return true end
    if combo == "HOME" then self:Jump(false) return true end
    if combo == "END" then self:Jump(true) return true end
    if ACTIVATE[combo] then self:Activate() return true end
    if combo == "LEFT" then return self:Change(-1) end
    if combo == "RIGHT" then return self:Change(1) end
    if combo == "SHIFT+LEFT" then return self:Change(-1, true) end
    if combo == "SHIFT+RIGHT" then return self:Change(1, true) end
    if (combo == "ESCAPE" or combo == "BACKSPACE") and #self.levels > 0 then return self:Pop() end
    if combo:match("^%u$") and (#self.levels > 0 or self.onClose or self.LetterJump) and #self.controls > 0 then
        self:JumpToLetter(combo)
        return true
    end
    if combo == "ESCAPE" and self.onClose then
        -- A mod screen (opened from the mod menu over the HUD) closes at its top level.
        Speech.Say(L("closed"), { interrupt = true })
        self.onClose()
        return true
    end
    return false
end

return ListScreen
