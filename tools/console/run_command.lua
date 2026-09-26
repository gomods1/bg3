-- Runs a mod command by id, as the mod menu would: prepend "ID='farther'".
for _, c in ipairs(BG3Access.Commands.Available()) do
    if c.id == ID then
        BG3Access.Commands.Run(c)
        return "ran " .. ID
    end
end
return "not available: " .. tostring(ID)
