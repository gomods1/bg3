-- Long rest supplies (widget MakeCamp, Game/Camp): what the rest does now (full or partial, the
-- game's own note), the supplies chosen ("40 of 40"), each supply item (Enter chooses it or not),
-- the game's auto selection, and the rest button (its label follows the choice: "Descanso
-- parcial" / "Descanso completo"). Escape is the game's (closes without resting).
local Game = Ext.Require("Game/Camp.lua")
local Loca = Ext.Require("Game/Loca.lua")
local Speech = Ext.Require("Core/Speech.lua")
local Strings = Ext.Require("Core/Strings.lua")
local ListScreen = Ext.Require("Screens/ListScreen.lua")
local Controls = Ext.Require("Screens/Controls.lua")

local L = Strings.Get

local Camp = ListScreen.Extend()
Camp.Widgets = { Game.Widget }

function Camp.New(widget)
    return setmetatable(ListScreen.New(widget.name, Loca.Text(Game.Labels.title) or L("screen_camp")), Camp)
end

local function full(r)
    return r and r.required > 0 and r.selected >= r.required
end

local function amountText()
    local r = Game.Read()
    if not r then return L("option_gone") end
    return L("camp_supplies", { label = Loca.Text(Game.Labels.supplies) or "", selected = r.selected, required = r.required })
end

local function supplyControl(i)
    local function line()
        local r = Game.Read()
        local s = r and r.supplies[i]
        if not s then return nil end
        return Strings.List({ s.name, s.count and s.count > 1 and L("camp_supply_count", { n = s.count }),
            s.selected > 0 and L("camp_supply_used", { n = s.selected }) })
    end
    return Controls.Item({
        kind = "button",
        describe = function() return line() or L("option_gone") end,
        activate = function()
            local was = amountText()
            if not Game.ToggleSupply(i) then
                Speech.Say(L("cannot_change"), { interrupt = true })
                return
            end
            Controls.SayWhenChanged(amountText, was)
        end,
    })
end

function Camp:Build()
    local r = Game.Read()
    if not r then return {} end
    local out = {
        Controls.Text(Loca.Text(Game.Labels.description)),
        Controls.Item({
            kind = "text",
            describe = function()
                local now = Game.Read()
                return Strings.List({ amountText(), Loca.Text(full(now) and Game.Labels.fullNote or Game.Labels.partialNote) })
            end,
        }),
    }
    for i = 1, #r.supplies do out[#out + 1] = supplyControl(i) end
    out[#out + 1] = Controls.Button({
        label = Loca.Text(Game.Labels.autoSelect) or "Auto",
        activate = function(done)
            local was = amountText()
            Game.AutoSelect(function(ok, reason)
                done(ok, reason)
                if ok then Controls.SayWhenChanged(amountText, was) end
            end)
        end,
    })
    out[#out + 1] = Controls.Item({
        kind = "button",
        describe = function()
            local label = Loca.Text(full(Game.Read()) and Game.Labels.fullRest or Game.Labels.partialRest)
            return Strings.List({ label, L("role_button") })
        end,
        activate = function()
            if not Game.Rest() then Speech.Say(L("cannot_change"), { interrupt = true }) end
        end,
    })
    return out
end

return Camp
