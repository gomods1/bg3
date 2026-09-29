-- New game difficulty (Game/Difficulty). The game's own Left/Right change the preset (the list
-- does not claim them); the selected preset is announced on open and whenever it changes. The rest
-- of the screen is the generic list.
local Game = Ext.Require("Game/Difficulty.lua")
local Speech = Ext.Require("Core/Speech.lua")
local Strings = Ext.Require("Core/Strings.lua")
local Generic = Ext.Require("Screens/Generic.lua")
local ListScreen = Ext.Require("Screens/ListScreen.lua")

local L = Strings.Get

local Difficulty = ListScreen.Extend(Generic)
Difficulty.Widgets = { Game.Widget }

function Difficulty.New(widget, page)
    -- Buttons only: the page's crossplay texts are hidden tooltips.
    local self = setmetatable(Generic.New(widget, page, { title = L("screen_difficulty"), buttonsOnly = true }), Difficulty)
    self.lastPreset = nil
    return self
end

local function presetText(p)
    return Strings.Sentences({ Strings.List({ p.title or "?", p.honour and L("honour_warning") }), p.description })
end

function Difficulty:Open()
    self:Refresh()
    local p = Game.Selected() or {}
    self.lastPreset = p.title
    Speech.Say(Strings.Sentences({ L("screen_difficulty"), presetText(p), Strings.Sentences(self:Help()) }))
end

function Difficulty:ReadAll()
    local parts = { L("screen_difficulty"), presetText(Game.Selected() or {}) }
    for _, c in ipairs(self.controls) do parts[#parts + 1] = c.Describe() end
    Speech.Say(Strings.Sentences(parts), { interrupt = true })
end

function Difficulty:Tick()
    ListScreen.Tick(self)
    local p = Game.Selected()
    if p and p.title and p.title ~= self.lastPreset then
        self.lastPreset = p.title
        Speech.Say(presetText(p), { interrupt = true })
    end
end

-- Left/Right are the game's own: they turn its preset carousel (the list moves with Up/Down).
function Difficulty:OnKey(combo)
    if combo == "LEFT" or combo == "RIGHT" then return false end
    return ListScreen.OnKey(self, combo)
end

function Difficulty:Help()
    local lines = Generic.Help(self)
    table.insert(lines, 1, L("help_difficulty"))
    return lines
end

return Difficulty
