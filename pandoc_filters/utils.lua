-- Shared utilities for pandoc filters
-- This module contains common functions used across multiple filters

-- Get the directory of this script to help with relative imports
local script_dir = debug.getinfo(1, "S").source:match("@(.*/)") or ""

local utils = {}

-- Environment variables (loaded once)
utils.destination_context = os.getenv("DESTINATION_CONTEXT") or ""
utils.destination_folder = os.getenv("DESTINATION_FOLDER") or ""
utils.source_folder = os.getenv("SOURCE_FOLDER") or ""
utils.current_source_file = os.getenv("CURRENT_SOURCE_FILE") or ""

-- Cache for file titles to avoid re-reading
local title_cache = {}

-- Helper function to calculate relative path between two files
function utils.calculate_relative_path(from_file, to_file)
    -- Remove .md extension and split paths into parts
    from_file = from_file:gsub("%.md$", "")
    to_file = to_file:gsub("%.md$", "")

    local from_parts = {}
    local to_parts = {}

    -- Split from_file path into parts (excluding filename)
    local from_dir = from_file:match("(.+)/[^/]+$") or ""
    if from_dir ~= "" then
        for part in from_dir:gmatch("[^/]+") do
            table.insert(from_parts, part)
        end
    end

    -- Split to_file path into parts
    for part in to_file:gmatch("[^/]+") do
        table.insert(to_parts, part)
    end

    -- Calculate how many directories to go up
    local up_count = #from_parts

    -- Build relative path
    local relative_parts = {}
    for i = 1, up_count do
        table.insert(relative_parts, "..")
    end

    -- Add the target path parts
    for _, part in ipairs(to_parts) do
        table.insert(relative_parts, part)
    end

    if #relative_parts == 0 then
        return to_file
    else
        return table.concat(relative_parts, "/")
    end
end

-- Helper function to extract title from a markdown or RST file
function utils.get_file_title(file_path)
    if title_cache[file_path] then
        return title_cache[file_path]
    end

    -- Clean the file path
    local clean_path = file_path:gsub("^/", "")

    -- Try both .md and .rst extensions in destination folder first
    local possible_paths = {
        utils.destination_folder .. "/" .. clean_path .. ".md",
        utils.destination_folder .. "/" .. clean_path .. ".rst"
    }

    -- Detect language from destination folder and add appropriate legacy path
    local language = utils.detect_language_from_path(utils.destination_folder)
    
    -- Try legacy path in source folder (relative to source folder)
    if utils.source_folder and utils.source_folder ~= "" then
        table.insert(possible_paths, utils.source_folder .. "/" .. clean_path .. ".rst")
    end

    for _, path in ipairs(possible_paths) do
        local file = io.open(path, "r")
        if file then
            local content = file:read("*all")
            file:close()

            -- Check if content was read successfully
            if not content then
                goto continue
            end

            -- Try to extract title from various formats
            local title = nil

            -- Look for markdown # header (find first line starting with #)
            for line in content:gmatch("[^\r\n]+") do
                local header_match = line:match("^#%s+(.+)$")
                if header_match then
                    title = header_match
                    title_cache[file_path] = title
                    return title
                end
            end

            -- Look for RST title (underlined with various characters)
            title = content:match("([^\n]+)\n[=#*+-~^'\"`:;<>.,?!@$%%&()_]+")
            if title then
                title = title:gsub("^%s+", ""):gsub("%s+$", "") -- trim whitespace
                title_cache[file_path] = title
                return title
            end

            -- Look for RST title (overlined and underlined)
            title = content:match("[=#*+-~^'\"`:;<>.,?!@$%%&()_]+\n([^\n]+)\n[=#*+-~^'\"`:;<>.,?!@$%%&()_]+")
            if title then
                title = title:gsub("^%s+", ""):gsub("%s+$", "") -- trim whitespace
                title_cache[file_path] = title
                return title
            end

            break -- Found the file, stop looking
        end
        ::continue::
    end

    -- Fallback: use filename as title
    local filename = file_path:match("([^/]+)$") or file_path
    filename = filename:gsub("%.md$", ""):gsub("%.rst$", ""):gsub("%-", " "):gsub("_", " ")
    -- Capitalize first letter of each word
    filename = filename:gsub("(%w)(%w*)", function(first, rest)
        return first:upper() .. rest:lower()
    end)

    title_cache[file_path] = filename
    return filename
end

-- Helper function to detect language from destination folder path
function utils.detect_language_from_path(path)
    if path:match("/ja/?$") then
        return "ja"
    elseif path:match("/fr/?$") then
        return "fr"
    elseif path:match("/es/?$") then
        return "es"
    elseif path:match("/pt/?$") then
        return "pt"
    elseif path:match("/de/?$") then
        return "de"
    else
        return "en" -- default to English
    end
end

-- Helper function to normalize file paths
function utils.normalize_path(path)
    -- Remove leading slash and clean up path
    return path:gsub("^/", ""):gsub("%.md$", ""):gsub("%.rst$", "")
end

-- Helper function to get current file path relative to destination folder
function utils.get_current_file_relative()
    local current_file = utils.destination_context

    if utils.destination_folder and utils.destination_folder ~= "" then
        -- If current_file starts with destination_folder, make it relative
        if current_file:find(utils.destination_folder, 1, true) == 1 then
            current_file = current_file:sub(#utils.destination_folder + 2) -- +2 to remove trailing slash
        end
    end

    return current_file
end

-- Helper function to trim whitespace from strings
function utils.trim(str)
    return str:gsub("^%s+", ""):gsub("%s+$", "")
end

-- Helper function to check if string starts with another string
function utils.starts_with(str, prefix)
    return str:sub(1, #prefix) == prefix
end

-- Helper function to check if string ends with another string
function utils.ends_with(str, suffix)
    return str:sub(-#suffix) == suffix
end

-- Helper function to split string by delimiter
function utils.split(str, delimiter)
    local result = {}
    local pattern = string.format("([^%s]+)", delimiter)

    for match in str:gmatch(pattern) do
        table.insert(result, match)
    end

    return result
end

-- Helper function to scan directory for files (used in anchor building)
function utils.scan_directory_for_files(dir, pattern)
    local files = {}
    local handle = io.popen("find " .. dir .. " -name '" .. pattern .. "' 2>/dev/null")
    if handle then
        for file in handle:lines() do
            table.insert(files, file)
        end
        handle:close()
    end

    -- Sort files to ensure deterministic processing order
    table.sort(files)

    return files
end

-- Helper function to read file content safely
function utils.read_file(file_path)
    local file = io.open(file_path, "r")
    if not file then
        return nil
    end

    local content = file:read("*all")
    file:close()

    return content
end

return utils