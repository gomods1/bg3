-- Loading saved games (widget LoadGame, gui::DCSavegames). Facts (verified 2026-09-24):
--   Opened in game with any DC's OpenLoadGameDialog (the game menu's button sends a CustomEvent).
--   DC: ExistingSaves[] (Title "QuickSave_8", Type QuickSave/AutoSave/..., TimeString,
--   PlayTimeString, LevelName handle = where, Difficulty handle, IsHonourMode, Validity,
--   OwnerPlaythrough), ExistingPlaythroughs[] (ProtagonistName, Saves[]), SelectedSave.
--   SE refuses every command of DCSavegames (NsHelpers: commands of that type read as nil), so the
--   save is chosen by setting SelectedSave and loaded with the game's own key for the Load button
--   (DoLoad, BoundEvent UIAccept = Enter, injected).
-- Saving (widget SaveGame, same DC fields plus CurrentPlaythroughID; verified 2026-09-24, a new
-- game "Mira"): each save's OwnerPlaythrough.PlaythroughString names its playthrough;
-- "Nueva partida guardada" (NewSaveBtn) sends a CustomEvent (a verified click) and opens the
-- SaveGamePopup (Guardar); "Guardar partida" (OverwriteSaveBtn, UIAccept) overwrites the
-- selected save after the game's own question.
local Vm = Ext.Require("Game/Vm.lua")
local Loca = Ext.Require("Game/Loca.lua")
local Input = Ext.Require("Game/Input.lua")

local SaveLoad = {}

SaveLoad.Widget = "LoadGame"
SaveLoad.SaveWidget = "SaveGame"

local function dc(widget) return Vm.WidgetDc(widget or SaveLoad.Widget) end

-- Sort key of a save's TimeString ("24/9/2026 19:57"): manual saves have SaveID -1, so the time
-- orders them (2026-09-24: a save named "Capilla" came last). Day and month are in the game
-- language's order (month first in English).
local function timeKey(save)
    local n = {}
    for d in tostring(Vm.Get(save, "TimeString") or ""):gmatch("%d+") do n[#n + 1] = tonumber(d) end
    if #n < 5 then return 0 end
    local ok, switches = pcall(Ext.Utils.GetGlobalSwitches)
    local monthFirst = ok and switches and switches.Language == "English"
    local day, month = n[1], n[2]
    if monthFirst then day, month = n[2], n[1] end
    return ((((n[3] * 100 + month) * 100 + day) * 100 + n[4]) * 100 + n[5])
end

-- The saves of a screen (widget: LoadGame by default), newest first (by their time; the game's
-- own order differs); only the current playthrough's when currentOnly.
local function saves(widget, currentOnly)
    local d = dc(widget)
    local current = currentOnly and tostring(Vm.Get(d, "CurrentPlaythroughID") or "")
    local list = {}
    for _, s in ipairs(Vm.List(d, "ExistingSaves")) do
        if not currentOnly or tostring(Vm.Get(Vm.Get(s, "OwnerPlaythrough"), "PlaythroughString") or "") == current then
            list[#list + 1] = s
        end
    end
    local keys = {}
    for _, sv in ipairs(list) do keys[sv] = timeKey(sv) end
    table.sort(list, function(a, b)
        if keys[a] ~= keys[b] then return keys[a] > keys[b] end
        return (Vm.Get(a, "SaveID") or 0) > (Vm.Get(b, "SaveID") or 0)
    end)
    return list
end

-- { { title, kind, time, playTime, place, selected, valid } } newest first. widget and
-- currentOnly as for saves().
function SaveLoad.Read(widget, currentOnly)
    local out = {}
    for _, s in ipairs(saves(widget, currentOnly)) do
        out[#out + 1] = {
            title = tostring(Vm.Get(s, "Title") or "?"),
            kind = Vm.Enum(s, "Type"),
            time = tostring(Vm.Get(s, "TimeString") or ""),
            playTime = tostring(Vm.Get(s, "PlayTimeString") or ""),
            place = Loca.Text(Vm.Get(s, "LevelName")),
            selected = Vm.Same(Vm.Get(dc(widget), "SelectedSave"), s),
            valid = Vm.Enum(s, "Validity") == "Valid",
        }
    end
    return out
end

-- Selects save i of the same list as SaveLoad.Read(widget, currentOnly), as a click on it.
-- Returns ok.
function SaveLoad.Select(i, widget, currentOnly)
    local s = saves(widget, currentOnly)[i]
    local d = dc(widget)
    if not (s and d) then return false end
    return pcall(function() d:SetProperty("SelectedSave", s) end)
end

-- Loads the selected save (the game's Enter for its Load button), or on the save screen
-- overwrites it (the game's Enter for "Guardar partida": it asks first). Returns ok.
function SaveLoad.LoadSelected()
    local key = Input.ScancodeFor("UIAccept")
    if not key then return false end
    Ext.Input.InjectKeyPress(key)
    return true
end

-- Opens the load screen from the game (any DC's OpenLoadGameDialog). Returns ok.
function SaveLoad.Open()
    return Vm.Run(Vm.WidgetDc("HotBar") or Vm.WidgetDc("GameMenu"), "OpenLoadGameDialog", nil)
end

return SaveLoad
