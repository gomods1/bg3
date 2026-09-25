-- Tutorial popups (widget ModalTutorial = Tutorial.xaml, gui::DCTutorial; verified 2026-09-24 with
-- the map tutorial): DC.Tutorial (gui::VMModalTutorial: Title, Description handles, Category,
-- TutorialID), DC.CurrentStep; commands FinishTutorial (also the game's Escape) and NextStep
-- (the button reads "Continuar" while steps remain). NextStep's CanExecute is true on the last
-- step too (measured on the one-step "Pruebas de habilidad" tutorial: it only advanced
-- CurrentStep, the text stayed); the step count is not readable from Lua (a Tag set in code).
local Vm = Ext.Require("Game/Vm.lua")

local Tutorial = {}

Tutorial.Widget = "ModalTutorial"
Tutorial.FinishLabel = "head66e6bg788dg4defg8488ga6b39108a91a"
Tutorial.ContinueLabel = "hc1e4c45fg54e3g49c1ga0aeg88d0eed38ae6"

local function dc() return Vm.WidgetDc(Tutorial.Widget) end

-- The tutorial's stable name ("Ending your Turn") for its title handle, from the static data
-- TutorialUnifiedEntry (TutorialName, DisplayTitle; 144 entries, verified 2026-09-24), or nil.
local nameByTitle = nil

function Tutorial.NameForTitle(handle)
    if not handle then return nil end
    if not nameByTitle then
        nameByTitle = {}
        pcall(function()
            for _, id in ipairs(Ext.StaticData.GetAll("TutorialUnifiedEntry")) do
                local e = Ext.StaticData.Get(id, "TutorialUnifiedEntry")
                local h = e.DisplayTitle and e.DisplayTitle.Handle and e.DisplayTitle.Handle.Handle
                if h then nameByTitle[tostring(h)] = tostring(e.TutorialName) end
            end
        end)
    end
    return nameByTitle[tostring(handle)]
end

-- { title, text, hasNext, name } or nil.
function Tutorial.Read()
    local d = dc()
    local t = Vm.Get(d, "Tutorial")
    if not t then return nil end
    return {
        name = Tutorial.NameForTitle(Vm.Get(t, "Title")),
        title = Vm.Text(t, "Title"),
        text = Vm.Text(t, "Description"),
        hasNext = Vm.CanExecute(Vm.Get(d, "NextStep"), nil) == true,
    }
end

function Tutorial.Finish() return Vm.Run(dc(), "FinishTutorial", nil) end
function Tutorial.Next() return Vm.Run(dc(), "NextStep", nil) end
function Tutorial.Previous() return Vm.Run(dc(), "PreviousStep", nil) end

return Tutorial
