--[[
Preserve RST comment markers as HTML comments in the output.
This allows us to find marker positions in the converted markdown files.

RST comments like:
    .. start-text
    .. end-text

Are converted to:
    <!-- start-text -->
    <!-- end-text -->
]]

function Para(elem)
    -- Check if this paragraph is just a comment
    if #elem.content == 1 and elem.content[1].t == "Str" then
        local text = elem.content[1].text
        -- Check if it looks like a marker comment that was converted
        if text:match("^%.%.%s+[a-zA-Z0-9_-]+$") then
            local marker = text:match("^%.%.%s+([a-zA-Z0-9_-]+)$")
            return pandoc.RawBlock('html', '<!-- ' .. marker .. ' -->')
        end
    end
    return elem
end

function RawBlock(elem)
    -- Catch RST comments that Pandoc might preserve as raw blocks
    if elem.format == 'rst' or elem.format == 'html' then
        local marker = elem.text:match("^%.%.%s+([a-zA-Z0-9_-]+)%s*$")
        if marker then
            return pandoc.RawBlock('html', '<!-- ' .. marker .. ' -->')
        end
    end
    return elem
end
