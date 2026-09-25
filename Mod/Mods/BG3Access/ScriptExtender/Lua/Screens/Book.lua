-- A book, note or letter (Game/Book): its title, then one line per paragraph; Up and Down read
-- them, Control R reads the whole text. Escape is the game's (closes the book).
local Game = Ext.Require("Game/Book.lua")
local Strings = Ext.Require("Core/Strings.lua")
local ListScreen = Ext.Require("Screens/ListScreen.lua")
local Controls = Ext.Require("Screens/Controls.lua")

local L = Strings.Get

local Book = ListScreen.Extend()
Book.Widgets = { Game.Widget }

function Book.New(widget)
    return setmetatable(ListScreen.New(widget.name, L("screen_book")), Book)
end

function Book:Build()
    local book = Game.Read()
    if not book then return {} end
    if book.title then self.title = book.title end
    local out = {}
    for _, p in ipairs(book.paragraphs) do out[#out + 1] = Controls.Text(p) end
    return out
end

return Book
