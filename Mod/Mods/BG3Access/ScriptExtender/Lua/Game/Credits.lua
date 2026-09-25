-- The credits (main menu, widget Credits). Facts (verified 2026-09-24): the DC's Credits[] holds
-- 2896 entries, each with Line (text with markup: "<font size='42'>Larian Studios</font>",
-- "Directed by", "<br><br>" spacers) and, for a heading, Content[] of entries whose Line is a
-- name ("SWEN VINCKE"). The game scrolls them as a film; they are read here as a list.
local Vm = Ext.Require("Game/Vm.lua")
local Text = Ext.Require("Core/Text.lua")

local Credits = {}

Credits.Widget = "Credits"

local function clean(line)
    local s = tostring(line or ""):gsub("<br%s*/?>", " "):gsub("<[^>]*>", "")
    s = Text.Clean(s)
    if not s or s:match("^%s*$") then return nil end
    return s
end

-- { { heading, names = { name } } } in the game's order, spacers left out.
function Credits.Read()
    local out = {}
    for _, e in ipairs(Vm.List(Vm.WidgetDc(Credits.Widget), "Credits")) do
        local heading = clean(Vm.Get(e, "Line"))
        local names = {}
        for _, n in ipairs(Vm.List(e, "Content")) do names[#names + 1] = clean(Vm.Get(n, "Line")) end
        if heading or #names > 0 then out[#out + 1] = { heading = heading, names = names } end
    end
    return out
end

return Credits
