-- The HUD's notification banner (widget NotificationWidget, Notification.xaml) and the area name.
-- Facts (verified 2026-09-24, arriving on the beach): CurrentPlayer.UIData.Notification
-- (ls.Notification): Type (Quest_Done, ... ; the XAML switches on it), TitlePrefix and Title
-- handles ("Completadas"), Message (Text handle "Escapa del nautiloide", TextContext),
-- ExtendedMessage (ls.VMContextTransString: Text template "[1]..." + Params[]), ExpGain, Amount,
-- ItemRarity. The VM keeps the last notification after the banner is gone.
-- Area: CurrentPlayer.SelectedCharacter.PlayerCharacterProperties.CurrentSubregionName (handle,
-- "Playa arrasada"; unknown handle where there is no subregion, e.g. the nautiloid).
local Vm = Ext.Require("Game/Vm.lua")
local Ui = Ext.Require("Game/Ui.lua")
local Player = Ext.Require("Game/Player.lua")
local Text = Ext.Require("Core/Text.lua")
local Loca = Ext.Require("Game/Loca.lua")
local Tutorial = Ext.Require("Game/Tutorial.lua")

local Notification = {}

-- The banner's text as shown (run-built TextBlocks under NotificationWidget) that starts with
-- prefix, or nil.
local function shownStartingWith(prefix)
    local root = Ui.FindByName(Ext.UI.GetRoot(), "ContentRoot")
    local widget = root and Ui.FindByName(root, "NotificationWidget")
    local found = nil
    local function walk(el, depth)
        if found or not el or depth > 60 then return end
        if tostring(el.Type) == "TextBlock" then
            local t = Ui.InlineText(el)
            if t and t:sub(1, #prefix) == prefix and #t > #prefix + 1 then found = t return end
        end
        for _, k in ipairs(Ui.Kids(el)) do walk(k, depth + 1) end
    end
    walk(widget, 0)
    return found
end

-- Fills "[n]" with the n-th parameter's text (as in the combat log). A parameter without text
-- ("Has usado: ." for a key that opened a door, 2026-09-25) is taken from the banner as shown.
local function render(ctx)
    local template = tostring(Vm.Get(ctx, "Text") or "")
    if template == "" then return nil end
    local params = Vm.List(ctx, "Params")
    local missing = false
    local s = template:gsub("%[(%d+)%]", function(n)
        local p = params[tonumber(n)]
        local t = p and tostring(Vm.Get(p, "Text") or "") or ""
        if t == "" then missing = true end
        return t
    end)
    if missing then
        local prefix = Text.Clean((template:match("^(.-)%[%d+%]") or ""))
        local shown = prefix ~= "" and shownStartingWith(prefix)
        if shown then return shown end
    end
    return Text.Clean(s)
end

-- { type, parts = { texts in display order }, expGain, amount } or nil.
function Notification.Read()
    local n = Vm.Get(Vm.Get(Player.Current(), "UIData"), "Notification")
    if not n then return nil end
    local parts = {}
    local function add(s) if s and s ~= "" then parts[#parts + 1] = s end end
    add(Vm.Text(n, "TitlePrefix"))
    add(Vm.Text(n, "Title"))
    -- Some messages are templates themselves ("[1] actualizaciones nuevas disponibles en el diario",
    -- 2026-09-24): [1] is the notification's Amount when it has one; an unfilled slot is dropped
    -- rather than spoken as "[1]" (the count was not readable after the fact: Amount 0).
    -- "Has usado: [1]." after a lock was picked with thieves' tools (2026-09-26): no Amount, and
    -- the item is not in the view model. The banner as shown is taken then; without it the line
    -- is left out ("Has usado: ." said nothing; the combat log names the tools).
    local amount = Vm.Get(n, "Amount")
    local message = Vm.Text(Vm.Get(n, "Message"), "Text")
    if message then
        local hasAmount = amount and amount > 0
        local prefix = Text.Clean((message:match("^(.-)%[%d+%]") or ""))
        if message:find("%[%d+%]") and not hasAmount and prefix ~= "" then
            message = shownStartingWith(prefix)
        else
            message = Text.Clean((message:gsub("%[1%]", hasAmount and tostring(amount) or ""):gsub("%[%d+%]", "")))
        end
    end
    add(message)
    add(render(Vm.Get(n, "ExtendedMessage")))
    return {
        type = Vm.Enum(n, "Type"),
        parts = parts,
        expGain = Vm.Get(n, "ExpGain"),
        amount = Vm.Get(n, "Amount"),
    }
end

-- The side tutorials (the panel beside the minimap, NotificationLib.xaml SideTutorialsStyle,
-- CurrentPlayer.UIData.UnifiedTutorials). Fields (verified 2026-09-24, stepping into grease):
-- Title, KBDescription, PadDescription (the controller's text: the same words here), KBInputHints,
-- PadInputHints (unknown handles), IsSideTutorial, LifeTime 12000. Read: Title and KBDescription.
-- { { key, texts = { }, fields = "k=v ..." } }.
local SIDE_TUTORIAL_TEXTS = { "Title", "KBDescription" }
local function isHandle(v)
    return type(v) == "string" and v:find("^h%x+g%x+g%x+g%x+g%x+$") ~= nil
end

function Notification.SideTutorials()
    local out = {}
    for _, t in ipairs(Vm.List(Vm.Get(Player.Current(), "UIData"), "UnifiedTutorials")) do
        local props = {}
        pcall(function() for k, v in pairs(t:GetAllProperties()) do props[#props + 1] = { k = k, v = v } end end)
        table.sort(props, function(a, b) return a.k < b.k end)
        local texts, fields = {}, {}
        for _, p in ipairs(props) do fields[#fields + 1] = p.k .. "=" .. tostring(p.v) end
        for _, name in ipairs(SIDE_TUTORIAL_TEXTS) do
            local v = Vm.Get(t, name)
            -- Cleaned: tutorial texts carry markup ("<LSTag Type="Image" Info="TutorialAdvantage"/>").
            local text = isHandle(v) and Loca.Text(v) or nil
            if text and text ~= "" then texts[#texts + 1] = text end
        end
        -- Keyed by its words: flags such as MustHide change while it is shown (measured).
        out[#out + 1] = { key = tostring(Vm.Get(t, "Title")) .. "|" .. tostring(Vm.Get(t, "KBDescription")), texts = texts, fields = table.concat(fields, " "),
            name = Tutorial.NameForTitle(Vm.Get(t, "Title")) }
    end
    return out
end

-- Party members with a level up waiting (Stats.Level.LevelUpAvailable; the game's portrait
-- shows a marker): { names }.
function Notification.LevelUps()
    local out = {}
    for _, c in ipairs(Vm.List(Player.Current(), "AssignedCharacters")) do
        if Vm.Get(Vm.Get(Vm.Get(c, "Stats"), "Level"), "LevelUpAvailable") == true then
            out[#out + 1] = Vm.Text(c, "Name") or "?"
        end
    end
    return out
end

-- The area name the minimap shows, or nil.
function Notification.AreaName()
    return Vm.Text(Vm.Get(Player.SelectedCharacter(), "PlayerCharacterProperties"), "CurrentSubregionName")
end

return Notification
