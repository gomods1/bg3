-- Screens/ListScreen sections (NAVIGATION.md): Tab / Shift+Tab between sections with their name and
-- size said first; Up/Down, Home/End stay inside the section; Left/Right move where the item has no
-- value; a list with one section leaves Tab to the game.
local Speech = Ext.Require("Core/Speech.lua")
local ListScreen = Ext.Require("Screens/ListScreen.lua")

local said = {}
Speech.Say = function(text) said[#said + 1] = text end

local function item(label, section, change)
    return { kind = "button", section = section, Describe = function() return label end, Change = change }
end

local function screen(controls)
    local s = ListScreen.New("(test)", "Test")
    s.Build = function() return controls end
    s:Refresh()
    s.index = 1
    return s
end

local function last() return said[#said] end

T.case("Tab goes to the next section and says its name and size first; wraps", function()
    local s = screen({ item("a1", "A"), item("a2", "A"), item("b1", "B") })
    T.truthy(s:OnKey("TAB"))
    T.eq(s.index, 3)
    T.truthy(last():find("B", 1, true) and last():find("b1", 1, true), "section and item: " .. last())
    T.truthy(s:OnKey("TAB"))
    T.eq(s.index, 1, "wraps to the first section")
    T.truthy(s:OnKey("SHIFT+TAB"))
    T.eq(s.index, 3)
end)

T.case("Up/Down and Home/End stay inside the section; the end item is said again", function()
    local s = screen({ item("a1", "A"), item("a2", "A"), item("b1", "B"), item("b2", "B") })
    s:OnKey("DOWN")
    T.eq(s.index, 2)
    s:OnKey("DOWN")
    T.eq(s.index, 2, "no move into the next section")
    T.eq(last(), "a2")
    s.index = 4
    s:OnKey("HOME")
    T.eq(s.index, 3)
    s:OnKey("END")
    T.eq(s.index, 4)
end)

T.case("Left/Right change a value, else move like Up/Down", function()
    local changed = 0
    local s = screen({ item("x", nil, function() changed = changed + 1 end), item("y"), item("z") })
    T.truthy(s:OnKey("RIGHT"))
    T.eq(changed, 1)
    T.eq(s.index, 1)
    s.index = 2
    T.truthy(s:OnKey("RIGHT"))
    T.eq(s.index, 3)
end)

T.case("A list with one section leaves Tab to the game", function()
    local s = screen({ item("a"), item("b") })
    T.falsy(s:OnKey("TAB"))
end)
