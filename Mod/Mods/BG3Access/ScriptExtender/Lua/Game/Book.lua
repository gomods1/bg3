-- Books, notes and letters (widget Book). Facts (verified 2026-09-24, "Aventuras ilustradas de
-- Balduran" in El Hueco, opened by a click on it): the DC's BookFullText holds the whole text
-- (<br> between paragraphs, the game's own markup), SourceItem is the item (Name handle); the
-- pages the game shows are only a layout of that text (ls:LSBook, PrevPage/NextPage). Entries and
-- IllustrationNames were empty for this book.
local Vm = Ext.Require("Game/Vm.lua")
local Text = Ext.Require("Core/Text.lua")

local Book = {}

Book.Widget = "Book"

-- { title, paragraphs = { text } } or nil when no book is open.
function Book.Read()
    local dc = Vm.WidgetDc(Book.Widget)
    if not dc then return nil end
    local text = Text.Clean(Vm.Get(dc, "BookFullText"))
    local paragraphs = {}
    for line in (text or ""):gmatch("[^\n]+") do
        local p = Text.Clean(line)
        if p then paragraphs[#paragraphs + 1] = p end
    end
    return { title = Vm.Text(Vm.Get(dc, "SourceItem"), "Name"), paragraphs = paragraphs }
end

return Book
