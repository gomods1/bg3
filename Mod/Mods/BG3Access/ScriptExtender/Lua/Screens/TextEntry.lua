-- Typing a short text (a character's name) with the keyboard, spoken as it is typed. Needed where
-- the game's own text box cannot be read back from Lua (its strings read as "ResStr_..." ids) and
-- SE has no text input event: the mod keeps the text itself and hands it over when confirmed.
-- Keys (SDL scancode names, so layout-independent only for these): letters A-Z (Shift: capital;
-- the first letter is a capital), digits, Space, Minus ("-"), Apostrophe ("'"); Backspace deletes
-- the last character (said); Up or Down read the text; Enter confirms; Escape cancels. Letters
-- with accents and "ñ" depend on the keyboard layout, which Lua cannot see: not typed (yet).
local Speech = Ext.Require("Core/Speech.lua")
local Strings = Ext.Require("Core/Strings.lua")

local L = Strings.Get

local TextEntry = {}
TextEntry.__index = TextEntry

local PUNCTUATION = { SPACE = " ", MINUS = "-", APOSTROPHE = "'" }

-- opts = { label, text (initial), maxLength, onDone = function(text) (nil: cancelled) }
function TextEntry.New(opts)
    local self = setmetatable({ label = opts.label, text = opts.text or "", maxLength = opts.maxLength or 20, onDone = opts.onDone }, TextEntry)
    return self
end

function TextEntry:Start()
    Speech.Say(L("entry_start", { label = self.label, text = self.text ~= "" and self.text or L("entry_empty") }), { interrupt = true })
end

-- The character a key combo types, or nil.
local function charOf(combo, first)
    local shift, key = combo:match("^(SHIFT%+)(.+)$")
    key = key or combo
    if key:match("^%u$") then return (shift or first) and key or key:lower() end
    local digit = key:match("^NUM_(%d)$") or key:match("^KP_(%d)$")
    if digit and not shift then return digit end
    if not shift then return PUNCTUATION[key] end
    return nil
end

-- Handles every key while typing; returns true (keys never reach the game meanwhile).
function TextEntry:OnKey(combo)
    if combo == "RETURN" or combo == "KP_ENTER" then
        self.finished = true
        self.onDone(self.text)
        return true
    end
    if combo == "ESCAPE" then
        self.finished = true
        Speech.Say(L("entry_cancelled"), { interrupt = true })
        self.onDone(nil)
        return true
    end
    if combo == "BACKSPACE" then
        if #self.text == 0 then
            Speech.Say(L("entry_empty"), { interrupt = true })
        else
            local removed = self.text:sub(-1)
            self.text = self.text:sub(1, -2)
            Speech.Say(L("entry_deleted", { char = removed == " " and L("entry_space") or removed }), { interrupt = true })
        end
        return true
    end
    if combo == "UP" or combo == "DOWN" then
        Speech.Say(self.text ~= "" and self.text or L("entry_empty"), { interrupt = true })
        return true
    end
    local c = charOf(combo, #self.text == 0 or self.text:sub(-1) == " ")
    if c then
        if #self.text >= self.maxLength then
            Speech.Say(L("entry_full", { n = self.maxLength }), { interrupt = true })
        else
            self.text = self.text .. c
            Speech.Say(c == " " and L("entry_space") or c, { interrupt = true })
        end
    end
    return true
end

return TextEntry
