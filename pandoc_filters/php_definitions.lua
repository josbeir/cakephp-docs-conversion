-- PHP definition directive filter
-- Handles php-static-def, php-function-def, and php-const-def custom directives

-- Helper function to extract text from a Para element
local function para_to_text(para)
    if para.t ~= "Para" then
        return nil
    end
    
    local text = ""
    local inlines = para.c or para.content or {}
    
    for _, inline in ipairs(inlines) do
        if inline.t == "Str" then
            -- Handle both old (inline.c) and new (inline.text) API
            text = text .. (inline.text or inline.c or "")
        elseif inline.t == "Space" then
            text = text .. " "
        end
    end
    
    return text
end

-- Process blocks and look for our custom directive Divs
function Pandoc(doc)
    local blocks = doc.blocks
    local result = {}
    
    for i, block in ipairs(blocks) do
        -- Check if this is a Div with one of our custom directive classes
        if block.t == "Div" then
            -- In Pandoc 3.x, block.classes is a list of class names
            -- block.content is the list of content blocks
            local classes = block.classes or {}
            local content_blocks = block.content or {}
            
            -- Check for php-static-def class
            if #classes > 0 and classes[1] == "php-static-def" and #content_blocks > 0 then
                local first_elem = content_blocks[1]
                
                if first_elem.t == "Para" then
                    local text = para_to_text(first_elem)
                    
                    if text then
                        -- The text is just the signature (class::method(params))
                        local class_part, method_and_params = text:match("^(.-)::(.+)$")
                        if class_part and method_and_params then
                            local method_name, params = method_and_params:match("^([^(]+)(.*)$")
                            
                            if method_name and params then
                                -- Escape backslashes
                                class_part = class_part:gsub("\\", "\\\\")
                                
                                -- Create formatted output
                                local formatted = "`static` " .. class_part .. "::**" .. method_name .. "**" .. params
                                table.insert(result, pandoc.Para({pandoc.RawInline("markdown", formatted)}))
                                
                                -- Add remaining content blocks as description
                                for j = 2, #content_blocks do
                                    table.insert(result, content_blocks[j])
                                end
                                
                                goto continue
                            end
                        end
                    end
                end
            
            -- Check for php-function-def class
            elseif #classes > 0 and classes[1] == "php-function-def" and #content_blocks > 0 then
                local first_elem = content_blocks[1]
                
                if first_elem.t == "Para" then
                    local text = para_to_text(first_elem)
                    
                    if text then
                        -- Escape backslashes
                        text = text:gsub("\\", "\\\\")
                        
                        -- Create formatted output - bold the entire function signature
                        local formatted = "`function` **" .. text .. "**"
                        table.insert(result, pandoc.Para({pandoc.RawInline("markdown", formatted)}))
                        
                        -- Add remaining content blocks as description
                        for j = 2, #content_blocks do
                            table.insert(result, content_blocks[j])
                        end
                        
                        goto continue
                    end
                end
            
            -- Check for php-const-def class
            elseif #classes > 0 and classes[1] == "php-const-def" and #content_blocks > 0 then
                local first_elem = content_blocks[1]
                
                if first_elem.t == "Para" then
                    local const_full = para_to_text(first_elem)
                    
                    if const_full then
                        -- Escape backslashes
                        const_full = const_full:gsub("\\", "\\\\")
                        
                        -- Split namespace and constant name - only bold the constant name
                        local namespace, const_name = const_full:match("^(.+)\\\\([^\\]+)$")
                        local formatted
                        if namespace and const_name then
                            formatted = "`constant` " .. namespace .. "\\\\**" .. const_name .. "**"
                        else
                            -- No namespace, just bold the whole thing
                            formatted = "`constant` **" .. const_full .. "**"
                        end
                        
                        table.insert(result, pandoc.Para({pandoc.RawInline("markdown", formatted)}))
                        
                        -- Add remaining content blocks as description
                        for j = 2, #content_blocks do
                            table.insert(result, content_blocks[j])
                        end
                        
                        goto continue
                    end
                end
            end
        end
        
        -- Not our directive, keep original block
        table.insert(result, block)
        
        ::continue::
    end
    
    return pandoc.Pandoc(result, doc.meta)
end
