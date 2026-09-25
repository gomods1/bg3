-- A character sheet (Game/Characters.Sheet) as spoken lines, shared by the character panel and
-- the Examine window.
local Strings = Ext.Require("Core/Strings.lua")

local L = Strings.Get

local SheetWords = {}

local function classNames(s)
    local out = {}
    for _, c in ipairs(s.classes) do
        out[#out + 1] = c.subclass and L("sheet_class_subclass", { class = c.name or "?", subclass = c.subclass }) or c.name
    end
    return Strings.List(out)
end

-- { text } for sheet s. withXp: the experience line (the party's own sheet).
function SheetWords.Lines(s, withXp)
    local out = {}
    local function add(text) if text and text ~= "" then out[#out + 1] = text end end
    if s.level and #s.classes == 0 then
        add(L("sheet_name_level_only", { name = s.name or "?", level = s.level }))
    elseif s.level then
        add(L("sheet_name_level", { name = s.name or "?", classes = classNames(s), level = s.level }))
    else
        add(s.name)
    end
    if s.race then add(L("sheet_race", { race = s.race })) end
    if s.background then add(L("sheet_background", { background = s.background })) end
    if withXp and s.xpNext and s.xpNext > 0 then add(L("sheet_xp", { xp = s.xp or 0, next = s.xpNext })) end
    if s.levelUp then add(L("level_up_available")) end
    if s.hp and s.hpMax then add(L("hp", { value = s.hp, max = s.hpMax })) end
    if s.ac and s.ac > 0 then add(L("sheet_ac", { n = s.ac })) end
    for _, a in ipairs(s.abilities) do
        add(Strings.List({
            L("cc_ability", { name = a.name or "?", value = a.value or 0, modifier = a.modifier or 0 }),
            a.save and L("sheet_save_proficient"),
        }))
    end
    for _, t in ipairs(s.traits) do add(t) end
    for _, a in ipairs(s.approvals) do
        add(Strings.Sentences({ L("sheet_approval", { name = a.name or "?", rating = a.rating or 0 }), a.description }))
    end
    return out
end

return SheetWords
