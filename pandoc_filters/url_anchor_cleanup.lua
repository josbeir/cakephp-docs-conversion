-- URL Anchor Cleanup filter
-- Converts backslashes to underscores in URL anchor fragments (after #)
-- This fixes broken links in PHPDoc comments like:
--   @link https://book.cakephp.org/.../hash.html#Cake\Utility\Hash::insert
-- Becomes:
--   @link https://book.cakephp.org/.../hash.html#Cake_Utility_Hash::insert

-- Process Link elements
function Link(elem)
    local url = elem.target
    
    -- Check if URL contains an anchor fragment with backslashes
    if url:match("#.*\\") then
        -- Convert backslashes to underscores only in the anchor fragment
        url = url:gsub("#([^#]*)", function(fragment)
            -- Replace backslashes with underscores
            return "#" .. fragment:gsub("\\+", "_")
        end)
        
        -- Update the link target
        elem.target = url
    end
    
    return elem
end

-- Process Code elements that might contain URLs in @link annotations
function Code(elem)
    local text = elem.text
    
    -- Check if this is a @link annotation or contains a URL with anchor
    if text:match("@link") or text:match("https?://[^%s]*#.*\\") then
        -- Convert backslashes to underscores in URL anchor fragments
        text = text:gsub("(https?://[^%s#]*)#([^%s]*)", function(base_url, fragment)
            -- Replace backslashes with underscores in the fragment
            return base_url .. "#" .. fragment:gsub("\\+", "_")
        end)
        
        -- Return modified Code element
        return pandoc.Code(text, elem.attr)
    end
    
    return elem
end

-- Process RawBlock elements (for code blocks)
function RawBlock(elem)
    if elem.format == "html" or elem.format == "markdown" then
        local text = elem.text
        
        -- Check if contains URLs with anchor fragments and backslashes
        if text:match("https?://[^%s]*#.*\\") then
            -- Convert backslashes to underscores in URL anchor fragments
            text = text:gsub("(https?://[^%s#]*)#([^%s]*)", function(base_url, fragment)
                -- Replace backslashes with underscores in the fragment
                return base_url .. "#" .. fragment:gsub("\\+", "_")
            end)
            
            return pandoc.RawBlock(elem.format, text)
        end
    end
    
    return elem
end

-- Process CodeBlock elements
function CodeBlock(elem)
    local text = elem.text
    
    -- Check if contains URLs with anchor fragments and backslashes
    if text:match("https?://[^%s]*#.*\\") then
        -- Convert backslashes to underscores in URL anchor fragments
        text = text:gsub("(https?://[^%s#]*)#([^%s]*)", function(base_url, fragment)
            -- Replace backslashes with underscores in the fragment
            return base_url .. "#" .. fragment:gsub("\\+", "_")
        end)
        
        return pandoc.CodeBlock(text, elem.attr)
    end
    
    return elem
end

-- Process Str elements that might contain raw URLs
function Str(elem)
    local text = elem.text
    
    -- Check if contains URLs with anchor fragments and backslashes
    if text:match("https?://[^%s]*#.*\\") then
        -- Convert backslashes to underscores in URL anchor fragments
        text = text:gsub("(https?://[^%s#]*)#([^%s]*)", function(base_url, fragment)
            -- Replace backslashes with underscores in the fragment
            return base_url .. "#" .. fragment:gsub("\\+", "_")
        end)
        
        return pandoc.Str(text)
    end
    
    return elem
end
