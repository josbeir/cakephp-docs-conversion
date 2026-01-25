-- Image path normalization filter
-- Converts /_static/img/ paths to root /
-- Also extracts proper alt text from figure captions

function Image(elem)
    -- Check if the image source starts with /_static/img/
    if elem.src:match("^/_static/img/") then
        -- Replace /_static/img/ with just /
        elem.src = elem.src:gsub("^/_static/img/", "/")
    end
    
    -- Fix alt text when Pandoc incorrectly uses the image path as alt
    -- This happens when RST figure directives are converted
    if elem.attr and elem.attr[3] and elem.attr[3].alt then
        local alt_text = elem.attr[3].alt
        -- If alt text looks like a file path, try to clean it up
        if alt_text:match("^/?_?static/img/") or alt_text:match("%.png$") or alt_text:match("%.jpg$") or alt_text:match("%.gif$") then
            -- Remove the path and just use the filename without extension as a fallback
            local filename = alt_text:match("([^/]+)%.[^.]+$") or ""
            -- Convert filename to readable text (replace hyphens/underscores with spaces, capitalize)
            filename = filename:gsub("[-_]", " ")
            filename = filename:gsub("(%a)([%w_']*)", function(first, rest)
                return first:upper() .. rest:lower()
            end)
            elem.attr[3].alt = filename
        end
    end
    
    return elem
end