-- Combat/Words: status lines from character snapshots (Game/Characters shape), no engine needed.
local Strings = Ext.Require("Core/Strings.lua")
local Words = Ext.Require("Combat/Words.lua")

local function tav()
    return {
        name = "Tav", uuid = "u1", relation = "Player", hp = 14.4, maxHp = 23,
        movement = 9, maxMovement = 9,
        resources = { { id = "ActionPoint", name = "Acción", value = 1, max = 1 }, { id = "BonusActionPoint", name = "Acción adicional", value = 0, max = 1 } },
        slots = { { level = 1, value = 2, max = 3 } },
        statuses = { { id = "RAGE", name = "Furia", turns = 10 }, { id = "BLESS", name = "Bendición" } },
    }
end

T.case("Status line in Spanish", function()
    Strings.SetLanguage("es")
    T.eq(Words.Status(tav()),
        "Tav, 14 de 23 puntos de golpe. Acción 1 de 1, Acción adicional 0 de 1, espacios de conjuro de nivel 1: 2 de 3, movimiento 9 de 9 metros. Furia 10 turnos, Bendición.")
end)

T.case("Status line in English, one turn left", function()
    Strings.SetLanguage("en")
    local s = tav()
    s.resources = { { id = "ActionPoint", name = "Action", value = 1, max = 1 }, { id = "BonusActionPoint", name = "Bonus action", value = 0, max = 1 } }
    s.statuses = { { id = "RAGE", name = "Rage", turns = 1 } }
    s.slots = {}
    s.maxMovement = 0
    T.eq(Words.Status(s), "Tav, 14 of 23 hit points. Action 1 of 1, Bonus action 0 of 1. Rage 1 turn.")
end)

T.case("No hit points left", function()
    Strings.SetLanguage("en")
    T.eq(Words.Hp({ hp = 0, maxHp = 10 }), "no hit points left")
    T.eq(Words.Statuses({ statuses = {} }), nil)
end)
