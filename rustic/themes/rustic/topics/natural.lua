-- ---------------------------------------------------------------------------
--
-- Theme: rustic
-- Topic: natural
--
-- ---------------------------------------------------------------------------

local utils = require ('themes.rustic.utils')

local themepark, theme, cfg = ...

themepark:add_table{
    name = 'natural_areas',
    ids_type = 'area',
    geom = 'multipolygon',
    columns = themepark:columns(utils.columns)
}

themepark:add_proc('area', function(object, data)
    local t = object.tags

    if not t.natural then
        return
    end

    local g = object:as_area():transform(3857)
    local a = utils.filteredTags(t)
    a["geom"] = g
    themepark:insert('natural_areas', a)
end)
