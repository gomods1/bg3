-- Text cleanup before speech: strip markup, collapse whitespace.
local Text = {}

function Text.Clean(s)
    if s == nil then return nil end
    s = tostring(s)
    s = s:gsub("<br%s*/?>", "\n")
    s = s:gsub("<[^>]+>", "")
    s = s:gsub("&lt;", "<"):gsub("&gt;", ">"):gsub("&amp;", "&"):gsub("&quot;", '"')
    s = s:gsub("[ \t]+", " "):gsub("\n%s*\n+", "\n"):gsub("^%s+", ""):gsub("%s+$", "")
    if s == "" then return nil end
    return s
end

return Text
