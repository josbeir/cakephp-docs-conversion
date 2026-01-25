-- Table cleanup filter: Remove redundant row separators and fix multi-line cells in GitHub Flavored Markdown tables
-- This filter removes table rows that contain only dashes (separator rows) except for the header separator
-- It also collapses multi-line cell content into single lines for GFM compatibility

-- Import shared utilities
-- Get the directory where this filter is located
local filter_dir = debug.getinfo(1, "S").source:match("@(.*/)")  or ""
-- Add the filter directory to the package path
package.path = package.path .. ";" .. filter_dir .. "?.lua"
-- Now require utils from the same directory
local utils = require('utils')

-- Helper function to collapse multi-line content in table cells
local function collapse_cell_content(cell_contents)
    -- Walk through the cell contents and replace any SoftBreak or LineBreak with Space
    local result = {}
    for _, block in ipairs(cell_contents) do
        local walked = pandoc.walk_block(block, {
            SoftBreak = function(elem)
                return pandoc.Space()
            end,
            LineBreak = function(elem)
                return pandoc.Space()
            end
        })
        table.insert(result, walked)
    end
    return result
end

-- Helper function to check if a table row contains only separator characters
local function is_separator_row(row)
    if not row or not row.cells then
        return false
    end

    -- row is a Row object, which has .cells property
    for _, cell in ipairs(row.cells) do
        -- Get the text content of the cell using cell.contents
        local cell_text = pandoc.utils.stringify(cell.contents)

        -- Remove whitespace
        cell_text = utils.trim(cell_text)

        -- Check if the cell contains only separator characters (-, |, spaces)
        -- An empty cell is also considered a separator
        if cell_text ~= "" and not cell_text:match("^[-|%s]+$") then
            return false
        end
    end

    return true
end

-- Process Table elements to remove redundant separator rows and fix multi-line cells
function Table(tbl)
    -- First, collapse multi-line content in all table cells
    -- Process header cells
    if tbl.head and tbl.head.rows then
        for _, row in ipairs(tbl.head.rows) do
            if row.cells then
                for _, cell in ipairs(row.cells) do
                    if cell.contents then
                        cell.contents = collapse_cell_content(cell.contents)
                    end
                end
            end
        end
    end

    -- Process body cells
    if tbl.bodies then
        for _, body in ipairs(tbl.bodies) do
            if body.body then
                for _, row in ipairs(body.body) do
                    if row.cells then
                        for _, cell in ipairs(row.cells) do
                            if cell.contents then
                                cell.contents = collapse_cell_content(cell.contents)
                            end
                        end
                    end
                end
            end
        end
    end

    -- Now remove redundant separator rows
    if not tbl.bodies or #tbl.bodies == 0 then
        return tbl
    end

    -- Process each table body
    for body_idx, body in ipairs(tbl.bodies) do
        if body.body and #body.body > 0 then
            local new_rows = {}
            local header_processed = false

            for _, row in ipairs(body.body) do
                -- Skip separator rows, but keep track if we've seen the header
                if is_separator_row(row) then
                    -- Skip this row - it's a redundant separator
                    -- Note: GFM tables already have their header separator handled by pandoc
                    goto continue
                else
                    -- Keep this row
                    table.insert(new_rows, row)
                    header_processed = true
                end

                ::continue::
            end

            -- Update the body with cleaned rows
            body.body = new_rows
        end
    end

    return tbl
end

-- Also handle any raw markdown that might contain malformed tables
function RawBlock(elem)
    if elem.format == "markdown" then
        local text = elem.text

        -- Look for table patterns with redundant separator rows
        -- Pattern: line with only dashes and pipes between actual table rows
        local lines = {}
        for line in text:gmatch("[^\r\n]+") do
            table.insert(lines, line)
        end

        local new_lines = {}
        local in_table = false
        local header_separator_found = false
        local pending_cell = nil

        for i, line in ipairs(lines) do
            -- Check if this looks like a table line
            if line:match("^%s*|.*|%s*$") then
                in_table = true

                -- Check if this is a separator row (contains only -, |, and spaces)
                local is_separator = line:match("^%s*|[%s|-]*|%s*$") ~= nil

                if is_separator then
                    -- This is a separator row
                    if not header_separator_found then
                        -- Keep the first separator (header separator)
                        table.insert(new_lines, line)
                        header_separator_found = true
                    end
                    -- Skip additional separators
                else
                    -- This is a data row, keep it
                    if pending_cell then
                        -- Append to previous line
                        new_lines[#new_lines] = new_lines[#new_lines] .. " " .. utils.trim(line)
                        pending_cell = nil
                    else
                        table.insert(new_lines, line)
                        pending_cell = nil
                    end
                end
            -- Check if this is a continuation line (indented text without pipes)
            elseif in_table and line:match("^%s+%S") and not line:match("|") then
                -- This is a continuation of the previous table cell
                -- Append it to the last line
                if #new_lines > 0 then
                    -- Remove trailing pipe from last line if exists
                    local last_line = new_lines[#new_lines]
                    if last_line:match("|%s*$") then
                        new_lines[#new_lines] = last_line:gsub("|%s*$", " " .. utils.trim(line) .. " |")
                    else
                        new_lines[#new_lines] = last_line .. " " .. utils.trim(line)
                    end
                    pending_cell = true
                end
            else
                -- Not a table line
                in_table = false
                header_separator_found = false
                pending_cell = nil
                table.insert(new_lines, line)
            end
        end

        local new_text = table.concat(new_lines, "\n")
        if new_text ~= text then
            return pandoc.RawBlock("markdown", new_text)
        end
    end

    return elem
end