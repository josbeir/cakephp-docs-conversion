-- Include filter: Convert Sphinx include directives to VitePress markdown file inclusion
-- Handles .. include:: directives with :start-after: and :end-before: options

-- Import shared utilities
-- Get the directory where this filter is located
local filter_dir = debug.getinfo(1, "S").source:match("@(.*/)") or ""
-- Add the filter directory to the package path
package.path = package.path .. ";" .. filter_dir .. "?.lua"
-- Now require utils from the same directory
local utils = require('utils')

-- Helper function to parse include directive options
local function parse_include_directive(text)
    local result = {
        path = nil,
        start_after = nil,
        end_before = nil
    }
    
    -- Extract the file path from .. include:: line
    local path = text:match("%.%. include::%s*([^\n]+)")
    if path then
        result.path = utils.trim(path)
    end
    
    -- Extract :start-after: option
    local start_after = text:match(":start%-after:%s*([^\n]+)")
    if start_after then
        result.start_after = utils.trim(start_after)
    end
    
    -- Extract :end-before: option
    local end_before = text:match(":end%-before:%s*([^\n]+)")
    if end_before then
        result.end_before = utils.trim(end_before)
    end
    
    return result
end

-- Helper function to convert RST path to markdown relative path
local function convert_include_path(rst_path)
    -- Remove leading slash (RST uses absolute paths from docs root)
    local clean_path = rst_path:gsub("^/", "")
    
    -- Change .rst extension to .md
    clean_path = clean_path:gsub("%.rst$", ".md")
    
    -- Calculate relative path from current file to target
    local current_file = utils.get_current_file_relative()
    local relative_path = utils.calculate_relative_path(current_file, clean_path)
    
    return relative_path
end

-- Helper function to create VitePress include syntax
local function create_vitepress_include(include_data)
    local path = convert_include_path(include_data.path)
    
    -- For now, we create a simple full-file include
    -- VitePress syntax: <!--@include: ./path/file.md-->
    local vitepress_include = "<!--@include: " .. path .. "-->"
    
    -- If we have markers, add them as comments for documentation
    if include_data.start_after or include_data.end_before then
        local comments = {}
        if include_data.start_after then
            table.insert(comments, "start-after: " .. include_data.start_after)
        end
        if include_data.end_before then
            table.insert(comments, "end-before: " .. include_data.end_before)
        end
        vitepress_include = vitepress_include .. "\n<!-- Include options: " .. table.concat(comments, ", ") .. " -->"
    end
    
    return vitepress_include
end

-- Process RawBlock elements to find include directives
function RawBlock(elem)
    -- Check if this is an RST raw block with include directive
    if elem.format == "rst" then
        local text = elem.text
        
        -- Check if this contains an include directive
        if text:match("^%s*%.%. include::") then
            -- Parse the include directive
            local include_data = parse_include_directive(text)
            
            if include_data.path then
                -- Create VitePress include syntax
                local vitepress_syntax = create_vitepress_include(include_data)
                
                -- Return as RawBlock with HTML format so it passes through
                return pandoc.RawBlock("html", vitepress_syntax)
            end
        end
    end
    
    return elem
end

-- Process Div elements that might contain include directives
function Div(elem)
    -- Check if this is an include directive div
    if elem.classes:includes("include") then
        -- Try to extract path from attributes
        local path = nil
        for _, attr in ipairs(elem.attributes) do
            if attr[1] == "literal_block" or attr[1] == "path" then
                path = attr[2]
                break
            end
        end
        
        -- If we found a path, process it
        if path then
            local include_data = {
                path = path,
                start_after = nil,
                end_before = nil
            }
            
            -- Check for options in attributes
            for _, attr in ipairs(elem.attributes) do
                if attr[1] == "start-after" then
                    include_data.start_after = attr[2]
                elseif attr[1] == "end-before" then
                    include_data.end_before = attr[2]
                end
            end
            
            -- Create VitePress include syntax
            local vitepress_syntax = create_vitepress_include(include_data)
            
            -- Return as RawBlock
            return pandoc.RawBlock("html", vitepress_syntax)
        end
    end
    
    return elem
end
