-- The Examine window (Game/Examine) as a list: for an item its name, the tooltip's short line,
-- what its spell does (a potion's healing), its description, value and weight; for a character
-- hit points, armour class, resistances and statuses. Escape is the game's (closes it).
local Game = Ext.Require("Game/Examine.lua")
local Loca = Ext.Require("Game/Loca.lua")
local Strings = Ext.Require("Core/Strings.lua")
local ListScreen = Ext.Require("Screens/ListScreen.lua")
local Controls = Ext.Require("Screens/Controls.lua")
local SpellWords = Ext.Require("Screens/SpellWords.lua")
local SheetWords = Ext.Require("Screens/SheetWords.lua")

local L = Strings.Get

local Examine = ListScreen.Extend()
Examine.Widgets = { Game.Widget }

local RESISTANCE_KEYS = { Resistant = "resist_resistant", Immune = "resist_immune", Vulnerable = "resist_vulnerable" }

function Examine.New(widget)
    return setmetatable(ListScreen.New(widget.name, L("screen_examine")), Examine)
end

function Examine:Build()
    local e = Game.Read()
    if not e then return {} end
    self.title = L("label_value", { label = L("screen_examine"), value = e.name })
    local lines = {}
    local function add(text) if text and text ~= "" then lines[#lines + 1] = Controls.Text(text) end end
    if e.item then
        local rarity = e.rarity and e.rarity ~= "Common" and Loca.Enum("RarityNameStyle", e.rarity)
        add(Strings.List({ e.count and e.count > 1 and L("item_count", { name = e.name, count = e.count }) or e.name, rarity }))
        add(e.short)
        if e.spell then add(SpellWords.Details(e.spell)) end
        add(e.description)
        add(Strings.List({ e.value and e.value > 0 and L("item_value", { gold = e.value }),
            e.weight and e.weight > 0 and L("item_weight", { kg = e.weight }) }))
    else
        for _, text in ipairs(e.sheet and SheetWords.Lines(e.sheet) or { e.name }) do add(text) end
        for _, kind in ipairs({ "Immune", "Resistant", "Vulnerable" }) do
            local list = e.resistances[kind]
            if list then add(L(RESISTANCE_KEYS[kind], { types = Strings.List(list) })) end
        end
    end
    if #e.statuses > 0 then add(Strings.List(e.statuses)) end
    return lines
end

return Examine
