-- Core/Recent: repeats within a window.
local Recent = Ext.Require("Core/Recent.lua")

T.case("The same text within the window is a repeat", function()
    local r = Recent.New(1000)
    T.falsy(r:Take("a", 0))
    T.truthy(r:Take("a", 500))
    T.falsy(r:Take("b", 500))
end)

T.case("After the window the text is new again", function()
    local r = Recent.New(1000)
    r:Take("a", 0)
    T.falsy(r:Take("a", 1000))
    T.truthy(r:Take("a", 1500), "the last take refreshed the time")
end)

T.case("Has does not record", function()
    local r = Recent.New(1000)
    T.falsy(r:Has("a", 0))
    r:Take("a", 0)
    T.truthy(r:Has("a", 999))
    T.falsy(r:Has("a", 1000))
end)

T.case("Old entries are pruned, Clear forgets everything", function()
    local r = Recent.New(100)
    r:Take("a", 0)
    r:Take("b", 50)
    r:Take("c", 200)
    T.eq(r.at.a, nil)
    T.eq(r.at.b, nil)
    T.eq(r.at.c, 200)
    r:Clear()
    T.falsy(r:Has("c", 200))
end)

T.case("Uses the game clock by default", function()
    local r = Recent.New(1000)
    Test.clock = 5000
    T.falsy(r:Take("a"))
    Test.clock = 5500
    T.truthy(r:Take("a"))
    Test.clock = 7000
    T.falsy(r:Take("a"))
end)
