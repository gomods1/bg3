-- Core/Poll: one Tick subscriber, per-poller intervals, guarded calls, statistics.
local Poll = Ext.Require("Core/Poll.lua")

T.case("Pollers run at their own interval, in registration order", function()
    local order = {}
    Poll.Every("fast", 100, function() order[#order + 1] = "fast" end)
    Poll.Every("slow", 250, function() order[#order + 1] = "slow" end)
    T.eq(#Test.ticks, 1, "one Tick subscription for every poller")
    Test.clock = 1000
    Test.tick()
    T.eq(order, { "fast", "slow" }, "both run on the first tick")
    Test.clock = 1100
    Test.tick()
    T.eq(order, { "fast", "slow", "fast" })
    Test.clock = 1150
    Test.tick()
    T.eq(order, { "fast", "slow", "fast" }, "too early for either")
    Test.clock = 1250
    Test.tick()
    T.eq(order, { "fast", "slow", "fast", "fast", "slow" })
end)

T.case("An error in one poller is logged and the others still run", function()
    local ran = false
    Poll.Every("bad", 0, function() error("boom") end)
    Poll.Every("good", 0, function() ran = true end)
    Test.clock = 5000
    Test.tick()
    T.truthy(ran)
    T.truthy(#Test.errors > 0)
    T.truthy(Test.errors[#Test.errors]:find("bad"), "the error names the poller")
end)

T.case("Stats count calls and time", function()
    Poll.ResetStats()
    Test.clock = 9000
    Test.tick()
    local byName = {}
    for _, s in ipairs(Poll.Stats()) do byName[s.name] = s end
    T.eq(byName.good.calls, 1)
    T.eq(byName.fast.ms, 100)
    T.truthy(Poll.Report():find("good %(every 0 ms%): 1 calls"))
end)

T.case("A poller must be a function", function()
    T.errors(function() Poll.Every("x", 100, nil) end)
end)
