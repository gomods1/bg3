-- Text cleanup before speech: strip markup, collapse whitespace.
local Text = {}

function Text.Clean(s)
    if s == nil then return nil end
    s = tostring(s)
    s = s:gsub("<br%s*/?>", "\n")
    s = s:gsub("<[^>]+>", "")
    s = s:gsub("&lt;", "<"):gsub("&gt;", ">"):gsub("&amp;", "&"):gsub("&quot;", '"')
    -- "contra Azotamentes.." (a name ending the game's template, then the template's own stop):
    -- one stop; an ellipsis stays.
    s = s:gsub("([^%.])%.%.$", "%1."):gsub("([^%.])%.%.([^%.])", "%1.%2")
    -- "Tav: : He oído gritos" (a template's "[1]: [2]" where the line brings its own colon).
    s = s:gsub(":%s*:", ":")
    s = s:gsub("[ \t]+", " "):gsub("\n%s*\n+", "\n"):gsub(" ?\n ?", "\n"):gsub("^%s+", ""):gsub("%s+$", "")
    if s == "" then return nil end
    return s
end

-- s without one final full stop ("." or the ideographic "。"), for titles the mod ends itself.
function Text.StripStop(s)
    if s == nil then return nil end
    s = tostring(s)
    if s:sub(-1) == "." and s:sub(-3) ~= "..." then return s:sub(1, -2) end
    if s:sub(-3) == "。" then return s:sub(1, -4) end
    return s
end

return Text
