-- Turn order list (Ctrl+T, a mod screen over the HUD): every combatant in turn order with relation,
-- HP and distance, "now" for those whose turn it is. Read-only (template_rpg rule 7): targeting
-- is a separate, explicit feature.
local Combat = Ext.Require("Game/Combat.lua")
local Words = Ext.Require("Combat/Words.lua")
local Speech = Ext.Require("Core/Speech.lua")
local Strings = Ext.Require("Core/Strings.lua")
local ListScreen = Ext.Require("Screens/ListScreen.lua")
local Controls = Ext.Require("Screens/Controls.lua")

local L = Strings.Get

local TurnOrder = ListScreen.Extend()

function TurnOrder.New(onClose)
    local self = setmetatable(ListScreen.New("(turnorder)", L("screen_turn_order")), TurnOrder)
    self.onClose = onClose
    return self
end

function TurnOrder:Build()
    local out = {}
    for i, c in ipairs(Combat.Combatants()) do
        local uuid = c.uuid
        out[#out + 1] = Controls.Item({
            kind = "text",
            describe = function()
                -- Re-read: HP and turns change while the list is open.
                for _, now in ipairs(Combat.Combatants()) do
                    if now.uuid == uuid then
                        return Strings.List({ Words.Combatant(now), now.currentTurn and L("turn_now") })
                    end
                end
                return L("option_gone")
            end,
        })
    end
    return out
end

return TurnOrder
