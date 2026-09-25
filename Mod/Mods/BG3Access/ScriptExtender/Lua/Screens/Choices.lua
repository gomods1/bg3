-- One-of-many choices in list screens (Game/Selectable snapshots): a section control
-- ("Subclase: Escuela de Evocación") whose Enter opens the choices as a sub-list, where Enter
-- selects. Used by character creation (race, class...) and the level up (subclass).
-- source = { list = fn -> { snapshots }, current = fn -> snapshot?, select = fn(i) -> ok }.
local Speech = Ext.Require("Core/Speech.lua")
local Strings = Ext.Require("Core/Strings.lua")
local Controls = Ext.Require("Screens/Controls.lua")

local L = Strings.Get

local Choices = {}

function Choices.Item(source, i)
    local function snap() return source.list()[i] end
    return Controls.Item({
        kind = "button",
        describe = function()
            local c = snap()
            if not c then return L("option_gone") end
            local unavailable = not c.available
                and (c.reason and L("label_value", { label = L("unavailable"), value = c.reason }) or L("unavailable"))
            return Strings.List({ c.label, c.selected and L("selected"), unavailable })
        end,
        activate = function()
            if not source.select(i) then
                Speech.Say(L("cannot_change"), { interrupt = true })
                return
            end
            Controls.SayLater(function()
                local cur = source.current()
                return cur and L("cc_selected", { choice = cur.label })
            end)
        end,
        details = function()
            local c = snap()
            return c and c.description
        end,
    })
end

local function build(source)
    return function()
        local out = {}
        for i = 1, #source.list() do out[i] = Choices.Item(source, i) end
        return out
    end
end

-- The section control of screen (a ListScreen): title, the current choice, and extra words
-- (e.g. "locked by the origin").
function Choices.Section(screen, title, source, extra)
    return Controls.Item({
        kind = "button",
        describe = function()
            local cur = source.current()
            return Strings.List({ L("cc_section", { section = title, value = cur and cur.label or L("none") }), extra })
        end,
        activate = function()
            local selectedAt = nil
            for i, c in ipairs(source.list()) do
                if c.selected then selectedAt = i end
            end
            screen:Push(title, build(source), selectedAt)
        end,
        details = function()
            local cur = source.current()
            return cur and cur.description
        end,
    })
end

return Choices
