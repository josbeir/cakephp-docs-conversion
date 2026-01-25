-- PHP domain directive filter
-- Converts preprocessed PHP directives (as raw HTML) to formatted markdown

local current_namespace = ""
local current_class = ""

-- Handle raw HTML blocks that contain PHP directives (preprocessed by AWK)
function RawBlock(elem)
    if elem.format == "html" then
        local text = elem.text
        
        -- Check if this is a PHP class, method, static, function, or constant directive
        if text:match("<code>class.*<strong>.*</strong>.*</code>") or 
           text:match("<code>method.*<strong>.*</strong>.*</code>") or
           text:match("<code>static.*<strong>.*</strong>.*</code>") or
           text:match("<code>function.*<strong>.*</strong>.*</code>") or
           text:match("<code>constant.*<strong>.*</strong>.*</code>") then
            -- Convert the HTML code block to proper markdown
            -- Extract the content inside <code>...</code>
            local code_content = text:match("<code>(.-)</code>")
            if code_content then
                -- Replace <strong>...</strong> with **...** for markdown
                local markdown_content = code_content:gsub("<strong>(.-)</strong>", "**%1**")
                
                -- Split the content to separate type prefix from the rest
                local type_prefix, rest
                -- Try class pattern first
                rest = markdown_content:match("^class (.+)$")
                if rest then
                    type_prefix = "class"
                else
                    -- Try method pattern
                    rest = markdown_content:match("^method (.+)$")
                    if rest then
                        type_prefix = "method"
                    else
                        -- Try static pattern
                        rest = markdown_content:match("^static (.+)$")
                        if rest then
                            type_prefix = "static"
                        else
                            -- Try function pattern
                            rest = markdown_content:match("^function (.+)$")
                            if rest then
                                type_prefix = "function"
                            else
                                -- Try constant pattern
                                rest = markdown_content:match("^constant (.+)$")
                                if rest then
                                    type_prefix = "constant"
                                end
                            end
                        end
                    end
                end
                
                if type_prefix and rest then
                    -- Convert single backslashes to double backslashes for proper FQDN display
                    rest = rest:gsub("\\", "\\\\")
                    -- Format as: `type` Rest with double backslashes for FQDN
                    local formatted = "`" .. type_prefix .. "` " .. rest
                    return pandoc.Para({pandoc.RawInline("markdown", formatted)})
                else
                    -- Fallback: convert single backslashes to double and return as raw markdown
                    markdown_content = markdown_content:gsub("\\", "\\\\")
                    return pandoc.Para({pandoc.RawInline("markdown", markdown_content)})
                end
            end
        end
    end
    
    return elem
end

-- Also handle inline PHP class references like :php:class:`ClassName`  
function Link(elem)
    -- Check if this is a PHP class reference
    if elem.target:match("^php:class:") then
        local class_ref = elem.target:gsub("^php:class:", "")
        -- Return as inline code with bold class name
        return pandoc.Code("**" .. class_ref .. "**")
    end
    
    return elem
end