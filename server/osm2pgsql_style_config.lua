local column_keys = {}
local table_keys = {}

local tables = {}

local function get_script_directory()
    local info = debug.getinfo(1, "S")
    return info.source:match("@(.*[/\\])") or ""
end

local script_dir = get_script_directory()

local file = io.open(script_dir .. "keys_columns.txt", "r")
local file_string = file:read("*all")
file:close()
for key in file_string:gmatch("[^\r\n]+") do
    column_keys[key] = true
end

file = io.open(script_dir .. "keys_tables.txt", "r")
file_string = file:read("*all")
file:close()
for key in file_string:gmatch("[^\r\n]+") do
    table_keys[key] = true
    column_keys[key] = true
end

local columns = {
    { column = 'tags', type = 'jsonb' },
    { column = 'area_3857', type = 'real' },
    { column = 'geom', type = 'geometry', proj = '3857', not_null = true },
    { column = 'geom_type', type = 'text', not_null = true }
}

for key, _ in pairs(column_keys) do
    table.insert(columns, { column = key, type = 'text' })
end

local misc_table = osm2pgsql.define_table{
    name = "misc",
    ids = { type = 'any', id_column = 'id' },
    columns = columns
}

for key, _ in pairs(table_keys) do
    tables[key] = osm2pgsql.define_table{
        name = key,
        ids = { type = 'any', id_column = 'id' },
        columns = columns
    }
end

function createRow(object)
    local row = {}
    for k, v in pairs(object.tags) do
        if column_keys[k] then
            -- `grab_tag` removes the item from `tags` so it won't redundantly appear in tags 
            row[k] = object:grab_tag(k)
        end
    end
    -- make sure we haven't already saved all the tags to columns
    if object.tags then
        row["tags"] = object.tags
    end
    return row
end

function insertRow(row)
    row["area_3857"] = row["geom"]:area()
    local did_insert = false
    for key, table in pairs(tables) do
        if row[key] and row[key] ~= 'no' then
            table:insert(row)
            did_insert = true
        end
    end
    if not did_insert then
        misc_table:insert(row)
    end
end

function osm2pgsql.process_node(object)
    local row = createRow(object)
    row["geom"] = object:as_point():transform(3857)
    row["geom_type"] = "point"
    insertRow(row)
end

function osm2pgsql.process_way(object)
    local areaTag = object.tags.area
    local row = createRow(object)
    if object.is_closed and areaTag ~= "no" then
        row["geom"] = object:as_polygon():transform(3857)
        if areaTag == "yes" then
            row["geom_type"] = "area"
        else
            row["geom_type"] = "closed_way"
        end
    else
        row["geom"] = object:as_linestring():transform(3857)
        row["geom_type"] = "line"
    end
    insertRow(row)
end

local allowed_relation_types = {
    multipolygon = true,
    boundary = true
}

function osm2pgsql.process_relation(object)
    if allowed_relation_types[object.tags.type] then
        local row = createRow(object)
        row["geom"] = object:as_multipolygon():transform(3857)
        row["geom_type"] = "area"
        insertRow(row)
    end
end

-- function osm2pgsql.select_relation_members(relation)
--     if relation.tags.type == 'route' then
--         return {
--             nodes = {},
--             ways = osm2pgsql.way_member_ids(relation)
--         }
--     end
-- end
