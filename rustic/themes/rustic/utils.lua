
-- The OSM keys we care about
local keys = {}

local file = io.open("keys.txt", "r")
local standalone_keys_string = file:read("*all")
file:close()

for key in standalone_keys_string:gmatch("[^\r\n]+") do
    table.insert(keys, key)
end

local file2 = io.open("lang_codes.txt", "r")
local lang_codes_string = file2:read("*all")
file2:close()

for code in lang_codes_string:gmatch("[^\r\n]+") do
    table.insert(keys, "name:" .. code)
end

local columns = {}
local allowedKeys = {}

for _, key in ipairs(keys) do
    table.insert(columns, { column = key, type = "text" })
    allowedKeys[key] = true
end

function filteredTags(tags)
    local filtered = {}

    for k, v in pairs(tags) do
        if allowedKeys[k] then
            filtered[k] = v
        end
    end

    return filtered
end

return { columns=columns, filteredTags=filteredTags }