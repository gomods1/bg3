-- Core/Keys: combo normalization, config bindings, the two layers (actions, then the router),
-- and the release of a claimed key being swallowed too.
local Keys = Ext.Require("Core/Keys.lua")
local Config = Ext.Require("Core/Config.lua")

T.case("Combo names: modifiers in a fixed order", function()
    T.eq(Keys.Combo("R", "Shift,Ctrl"), "CTRL+SHIFT+R")
    T.eq(Keys.Combo("DOWN", ""), "DOWN")
    T.eq(Keys.Combo("F1", "Alt"), "ALT+F1")
end)

T.case("Default config binds the menu to Ctrl+M and leaves most commands unbound", function()
    Config.Load()
    T.eq(Config.KeysFor("menu"), { "CTRL+M" })
    T.eq(Config.KeysFor("nearby"), {})
    T.truthy(Test.files["BG3Access/config.json"], "a missing config file is written with the defaults")
end)

T.case("Actions run on their combo and the press is prevented, releases too", function()
    local ran = 0
    Keys.Action("menu", function() ran = ran + 1 end)
    Keys.Start()
    T.truthy(Test.key({ Key = "M", Modifiers = "Ctrl" }), "the press is claimed")
    T.eq(ran, 1)
    T.truthy(Test.key({ Key = "M", Modifiers = "Ctrl", Pressed = false }), "the release of a claimed key is swallowed")
    T.falsy(Test.key({ Key = "M", Modifiers = "Ctrl", Pressed = false }), "a second release is not")
    T.truthy(Test.key({ Key = "M", Modifiers = "Ctrl", Repeat = true }), "a repeat is claimed")
    T.eq(ran, 1, "but does not run the action again")
    T.eq(Keys.CombosFor("menu"), { "CTRL+M" })
end)

T.case("Unbound keys go to the router; a handled key is prevented, an unhandled one is not", function()
    local seen = {}
    Keys.Router = function(combo)
        seen[#seen + 1] = combo
        return combo == "DOWN"
    end
    T.truthy(Test.key({ Key = "DOWN" }))
    T.falsy(Test.key({ Key = "F2" }))
    T.eq(seen, { "DOWN", "F2" })
    T.falsy(Test.key({ Key = "F2", Pressed = false }), "an unclaimed release passes")
end)

T.case("A router error is logged, not raised", function()
    Keys.Router = function() error("boom") end
    T.falsy(Test.key({ Key = "UP" }))
    T.truthy(#Test.errors > 0)
end)

T.case("Key observers see the presses the mod did not take", function()
    Keys.Router = function() return false end
    local observed = {}
    Keys.Observer = function(combo) observed[#observed + 1] = combo end
    Test.key({ Key = "F3" })
    Test.key({ Key = "M", Modifiers = "Ctrl" }) -- a mod action: not observed
    Test.key({ Key = "F3", Pressed = false })     -- a release: not observed
    T.eq(observed, { "F3" })
end)
