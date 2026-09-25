-- The loading screen (widget "root", ls.LoadingScreen). Facts (verified 2026-09-24, quick load in
-- act 1): LoadingHints[] of { CtxTransText } (context strings), VisibileHintIndex (the game's
-- spelling; 0-based) = the hint on screen; the hints rotate during a long load. Also LevelName,
-- LoadingState ("Level"), Progress.
local Vm = Ext.Require("Game/Vm.lua")

local Loading = {}

-- The hint on screen, or nil.
function Loading.Hint()
    local dc = Vm.WidgetDc("root")
    local i = Vm.Get(dc, "VisibileHintIndex")
    local hint = i and Vm.List(dc, "LoadingHints")[i + 1]
    return hint and Vm.ContextText(Vm.Get(hint, "CtxTransText")) or nil
end

return Loading
