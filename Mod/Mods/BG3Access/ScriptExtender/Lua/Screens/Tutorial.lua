-- Tutorial popups (Game/Tutorial): title and text are read on open; Continue / Finish buttons.
-- The texts speak of the mouse; rewriting them into the mod's keys is M8.
local Game = Ext.Require("Game/Tutorial.lua")
local Loca = Ext.Require("Game/Loca.lua")
local Speech = Ext.Require("Core/Speech.lua")
local Strings = Ext.Require("Core/Strings.lua")
local TutorialHints = Ext.Require("Screens/TutorialHints.lua")
local ListScreen = Ext.Require("Screens/ListScreen.lua")
local Controls = Ext.Require("Screens/Controls.lua")

local L = Strings.Get

local Tutorial = ListScreen.Extend()
Tutorial.Widgets = { Game.Widget }

function Tutorial.New(widget)
    return setmetatable(ListScreen.New(widget.name, widget.name), Tutorial)
end

function Tutorial:Build()
    local t = Game.Read()
    if not t then return {} end
    self.title = t.title or self.widget
    local out = { Controls.Text(Strings.Sentences({ t.text or "", TutorialHints.For(t.name) })) }
    if t.hasNext and not self.lastStep then
        out[#out + 1] = Controls.Button({
            label = Loca.Text(Game.ContinueLabel) or "Continue",
            activate = function(done)
                local before = t.text
                local ok = Game.Next()
                done(ok, "reason_unavailable")
                if ok then
                    Controls.SayLater(function()
                        local n = Game.Read()
                        if n and n.text == before then
                            -- It was the last step (Game/Tutorial: no step count): step back
                            -- and offer only Finish.
                            Game.Previous()
                            self.lastStep = true
                            self:Refresh()
                            self.index = #self.controls
                            return L("tutorial_last_page")
                        end
                        self:Refresh()
                        return n and n.text
                    end)
                end
            end,
        })
    end
    out[#out + 1] = Controls.Button({
        label = Loca.Text(Game.FinishLabel) or "Finish",
        activate = function(done) done(Game.Finish(), "reason_unavailable") end,
    })
    return out
end

-- Enter before anything is chosen: the first button (Continue, else Finish). The popup was read
-- on open, and Enter said "nothing selected" over the dice roll at the Blighted Village
-- (2026-09-24).
function Tutorial:Activate()
    if not self:Current() then self.index = math.min(2, #self.controls) end
    ListScreen.Activate(self)
end

-- Title and text first: a tutorial is read, not browsed.
function Tutorial:Announce()
    local t = Game.Read()
    if not t then return end
    Speech.Say(Strings.Sentences({ t.title, t.text, TutorialHints.For(t.name), Strings.Sentences(self:Help()) }))
end

return Tutorial
