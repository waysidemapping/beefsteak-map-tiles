local table_defs = {
    amenity = {
        impliesArea = {}
    },
    shop = {
        impliesArea = {}
    },
    leisure = {
        impliesArea = {}
    },
    tourism = {
        impliesArea = {}
    },
    office = {
        impliesArea = {}
    },
    education = {
        impliesArea = {}
    },
    healthcare = {
        impliesArea = {}
    },
    club = {
        impliesArea = {}
    },
    craft = {
        impliesArea = {}
    },
    aerialway = {},
    aeroway = {
        impliesArea = {
            jet_bridge = true,
            parking_position = true,
            runway = true,
            taxiway = true
        }
    },
    barrier = {},
    building = {
        impliesArea = {}
    },
    highway = {},
    route = {},
    information = {},
    man_made = {
        impliesArea = {
            breakwater = true,
            cutline = true,
            dyke = true,
            embankment = true,
            gantry = true,
            goods_conveyor = true,
            groyne = true,
            pier = true,
            pipeline = true,
            yes = true
        }
    },
    natural = {
        impliesArea = {
            cliff = true,
            coastline = true,
            gorge = true,
            ridge = true,
            strait = true,
            tree_row = true,
            valley = true
        }
    },
    railway = {},
    waterway = {}
}

-- The OSM keys we care about
local keys = {}

-- Function to get the directory of the current script
local function get_script_directory()
    local info = debug.getinfo(1, "S")
    return info.source:match("@(.*[/\\])") or ""
end

local script_dir = get_script_directory()

local file = io.open(script_dir .. "keys.txt", "r")
local standalone_keys_string = file:read("*all")
file:close()

for key in standalone_keys_string:gmatch("[^\r\n]+") do
    table.insert(keys, key)
end

-- local file2 = io.open(script_dir .. "lang_codes.txt", "r")
-- local lang_codes_string = file2:read("*all")
-- file2:close()

-- for code in lang_codes_string:gmatch("[^\r\n]+") do
--     table.insert(keys, "name:" .. code)
-- end

local columns = {
    { column = 'geom', type = 'geometry', proj = '3857', not_null = true },
    { column = 'geom_type', type = 'text', not_null = true }
}
local allowed_keys = {}

for _, key in ipairs(keys) do
    table.insert(columns, { column = key, type = "text" })
    allowed_keys[key] = true
end

function filteredTags(tags)
    local filtered = {}

    for k, v in pairs(tags) do
        if allowed_keys[k] then
            filtered[k] = v
        end
    end

    return filtered
end

for key, table_def in pairs(table_defs) do
    table_def.table = osm2pgsql.define_table{
        name = key,
        ids = { type = 'any', id_column = 'id' },
        columns = columns
    }
end

function osm2pgsql.process_node(object)
    for key, table_def in pairs(table_defs) do
        if object.tags[key] and object.tags[key] ~= 'no' then
            local obj = filteredTags(object.tags)
            obj["geom"] = object:as_point():transform(3857)
            obj["geom_type"] = "point"
            table_def.table:insert(obj)
        end
    end
end

function osm2pgsql.process_way(object)
    for key, table_def in pairs(table_defs) do
        if object.tags[key] and object.tags[key] ~= 'no' then
            -- only treat as area if geometry is closed and tagging suggests it's an area
            if object.is_closed and object.tags.area ~= 'no' and (object.tags.area == 'yes' or (table_def.impliesArea and not table_def.impliesArea[object.tags[key]]) ) then
                local obj = filteredTags(object.tags)
                obj["geom"] = object:as_multipolygon():transform(3857)
                obj["geom_type"] = "area"
                table_def.table:insert(obj)
            else
                local obj = filteredTags(object.tags)
                obj["geom"] = object:as_linestring():transform(3857)
                obj["geom_type"] = "line"
                table_def.table:insert(obj)
            end
        end
    end
end

function osm2pgsql.process_relation(object)
    for key, table_def in pairs(table_defs) do
        if object.tags[key] and object.tags[key] ~= 'no' then
            if object.tags.type == 'multipolygon' then
                local obj = filteredTags(object.tags)
                obj["geom"] = object:as_multipolygon():transform(3857)
                obj["geom_type"] = "area"
                table_def.table:insert(obj)
            end
        end
    end
end
