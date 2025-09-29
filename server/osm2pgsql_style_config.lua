local node_table = osm2pgsql.define_table({
    name = 'node',
    ids = { type = 'node', id_column = 'id', create_index = 'primary_key' },
    columns = {
        { column = 'tags', type = 'hstore', not_null = true },
        { column = 'geom', type = 'point', proj = '3857', not_null = true }
    },
    indexes = {
        { column = 'tags', method = 'gin' },
        { column = 'geom', method = 'gist' }
    }
})

local way_table = osm2pgsql.define_table({
    name = 'way',
    ids = { type = 'way', id_column = 'id', create_index = 'primary_key' },
    columns = {
        { column = 'tags', type = 'hstore', not_null = true },
        { column = 'geom', type = 'geometry', proj = '3857', not_null = true },
        { column = 'is_closed', type = 'boolean', not_null = true },
        { column = 'is_explicit_area', type = 'boolean', not_null = true },
        { column = 'is_explicit_line', type = 'boolean', not_null = true },
        { column = 'area_3857', type = 'real', not_null = true },
    --    { column = 'length_3857', type = 'real', not_null = true },
    --    { column = 'bbox', type = 'text', sql_type = 'GEOMETRY(Polygon, 3857)' },
        { column = 'bbox_diagonal_length', type = 'real', not_null = true },
        { column = 'point_on_surface', sql_type = 'GEOMETRY(Point, 3857)', create_only = true }
    },
    indexes = {
        { column = 'tags', method = 'gin' },
        { column = 'geom', method = 'gist' },
        { column = 'area_3857', method = 'btree' },
    --    { column = 'bbox', method = 'gist' },
        { column = 'bbox_diagonal_length', method = 'btree' },
        { column = 'point_on_surface', method = 'gist' }
    }
})
-- we need super fast coastline selection so store them redundantly here
local coastline_table = osm2pgsql.define_table({
    name = 'coastline',
    ids = { type = 'way', id_column = 'id', create_index = 'primary_key' },
    columns = {
        { column = 'geom', type = 'linestring', proj = '3857', not_null = true },
        { column = 'area_3857', type = 'real', not_null = true },
    --    { column = 'length_3857', type = 'real', not_null = true }
    },
    indexes = {
        { column = 'geom', method = 'gist' },
        { column = 'area_3857', method = 'btree' }
    }
})

local area_relation_table = osm2pgsql.define_table({
    name = 'area_relation',
    ids = { type = 'relation', id_column = 'id', create_index = 'primary_key' },
    columns = {
        { column = 'tags', type = 'hstore', not_null = true },
        { column = 'geom', type = 'multipolygon', proj = '3857', not_null = true },
        { column = 'area_3857', type = 'real' },
        { column = 'label_node_id', type = 'int8' },
        { column = 'label_point', sql_type = 'GEOMETRY(Point, 3857)', create_only = true }
    },
    indexes = {
        { column = 'tags', method = 'gin' },
        { column = 'geom', method = 'gist' },
        { column = 'area_3857', method = 'btree' },
        { column = 'label_node_id', method = 'btree' },
        { column = 'label_point', method = 'gist' }
    }
})

local non_area_relation_table = osm2pgsql.define_table({
    name = 'non_area_relation',
    ids = { type = 'relation', id_column = 'id', create_index = 'primary_key' },
    columns = {
        { column = 'tags', type = 'hstore', not_null = true },
        { column = 'geom', type = 'geometrycollection', proj = '3857' },
        { column = 'bbox', type = 'text', sql_type = 'GEOMETRY(Polygon, 3857)' },
        { column = 'bbox_centerpoint_on_surface', sql_type = 'GEOMETRY(Point, 3857)', create_only = true },
        { column = 'bbox_diagonal_length', type = 'real' }
    },
    indexes = {
        { column = 'tags', method = 'gin' },
        { column = 'geom', method = 'gist' },
        { column = 'bbox', method = 'gist' },
        { column = 'bbox_centerpoint_on_surface', method = 'gist' },
        { column = 'bbox_diagonal_length', method = 'btree' }
    }
})

local node_relation_member_table = osm2pgsql.define_table({
    name = 'node_relation_member',
    ids = { type = 'relation', id_column = 'relation_id', create_index = 'always' },
    columns = {
        { column = 'member_index', type = 'int2' },
        { column = 'member_id', type = 'int8' },
        { column = 'member_role', type = 'text' }
    },
    indexes = {
        { column = 'member_id', method = 'btree', include = 'relation_id' },
        { column = 'member_role', method = 'btree' }
    }
})

local way_relation_member_table = osm2pgsql.define_table({
    name = 'way_relation_member',
    ids = { type = 'relation', id_column = 'relation_id', create_index = 'always' },
    columns = {
        { column = 'member_index', type = 'int2' },
        { column = 'member_id', type = 'int8' },
        { column = 'member_role', type = 'text' }
    },
    indexes = {
        { column = 'member_id', method = 'btree', include = 'relation_id' },
        { column = 'member_role', method = 'btree' }
    }
})

local relation_relation_member_table = osm2pgsql.define_table({
    name = 'relation_relation_member',
    ids = { type = 'relation', id_column = 'relation_id', create_index = 'always' },
    columns = {
        { column = 'member_index', type = 'int2' },
        { column = 'member_id', type = 'int8' },
        { column = 'member_role', type = 'text' }
    },
    indexes = {
        { column = 'member_id', method = 'btree', include = 'relation_id' },
        { column = 'member_role', method = 'btree' }
    }
})

local multipolygon_relation_types = {
    multipolygon = true,
    boundary = true
}

-- Format the bounding box we get from calling get_bbox() on the parameter
-- in the way needed for the PostgreSQL/PostGIS box2d type.
function format_bbox(minX, minY, maxX, maxY)
    if minX == nil then
        return nil
    end
    return 'POLYGON(('.. tostring(minX) .. ' '.. tostring(minY) .. ', '.. tostring(minX) .. ' '.. tostring(maxY) .. ', '.. tostring(maxX) .. ' '.. tostring(maxY) .. ', '.. tostring(maxX) .. ' '.. tostring(minY) .. ', '.. tostring(minX) .. ' '.. tostring(minY) .. '))'
end

-- runs only on tagged nodes or nodes specified by `select_relation_members`
function osm2pgsql.process_node(object)
    node_table:insert({
        tags = object.tags,
        geom = object:as_point():transform(3857)
    })
end

function process_way(object)
    local line_geom = object:as_linestring():transform(3857)
 --   local length_3857 = line_geom:length()

    local area_geom = nil
    local area_3857 = 0
    local geom = line_geom
    if object.is_closed then
        -- `area()` always returns 0 for linestrings so we need to convert to polygon
        area_geom = object:as_polygon():transform(3857)
        area_3857 = area_geom:area()
        geom = area_geom
    end

    if object.tags.natural == 'coastline' then
        coastline_table:insert({
            area_3857 = area_3857,
 --           length_3857 = length_3857,
            geom = line_geom
        })
    end

    local minX, minY, maxX, maxY = geom:get_bbox()
    way_table:insert({
        tags = object.tags,
        geom = geom,
        is_closed = object.is_closed,
        is_explicit_area = object.is_closed and (object.tags.area == 'yes' or object.tags.building ~= nil),
        is_explicit_line = not object.is_closed or object.tags.area == 'no',
        area_3857 = area_3857,
      --  length_3857 = length_3857,
      --  bbox = format_bbox(minX, minY, maxX, maxY),
        bbox_diagonal_length = math.sqrt(math.pow(maxX - minX, 2) + math.pow(maxY - minY, 2))
    })
end

-- runs only on tagged ways or ways specified by `select_relation_members`
function osm2pgsql.process_way(object)
    process_way(object)
end
-- relation member may be untagged and we want to include them
function osm2pgsql.process_untagged_way(object)
    process_way(object)
end

-- only runs on tagged relations
function osm2pgsql.process_relation(object)
    local relType = object.tags.type
    if relType then

        local label_node_id = nil

        for i, member in ipairs(object.members) do
            local row = {
                relation_id = object.id,
                member_id = member.ref,
                member_index = i,
                member_role = member.role
            }
            if member.type == 'n' then
                if member.role == 'label' then
                    label_node_id = member.ref
                end
                node_relation_member_table:insert(row)
            elseif member.type == 'w' then
                way_relation_member_table:insert(row)
            else
                relation_relation_member_table:insert(row)
            end
        end

        if multipolygon_relation_types[relType] then
            local geom = object:as_multipolygon():transform(3857)

            local largestArea = 0
            local largestPart = nil
            for g in geom:geometries() do
                local area = g:area()
                if area > largestArea then
                    largestArea = area
                    largestPart = g
                end
            end

            local row = {
                tags = object.tags,
                label_node_id = label_node_id,
                geom = geom,
                area_3857 = geom:area()
            }
            area_relation_table:insert(row)
        else
            local geom = object:as_geometrycollection():transform(3857)
            local minX, minY, maxX, maxY = geom:get_bbox()
            non_area_relation_table:insert({
                id = object.id,
                tags = object.tags,
                geom = geom,
                bbox = format_bbox(minX, minY, maxX, maxY),
                bbox_diagonal_length = math.sqrt(math.pow(maxX - minX, 2) + math.pow(maxY - minY, 2))
            })
        end

       
    end
end

-- Label nodes are sometimes untagged so we need to manually send them to `process_node`
function osm2pgsql.select_relation_members(object)
    local node_member_ids = {}

    for _, member in ipairs(object.members) do
        if member.role == 'label' and member.type == 'n' then
            table.insert(node_member_ids, member.ref)
        end
    end

    if #node_member_ids > 0 then
        return {
            nodes = node_member_ids,
            ways = {}
        }
    end
end

