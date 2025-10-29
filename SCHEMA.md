# 🔪🍅 Heirloom map tile schema

*This schema is in active development and is not yet versioned. Users should expect that changes may occur at any time without notice. This schema is never expected to become fully stable since tagging changes are inherent to OpenStreetMap.*

## Concepts

### Top-level tags

OpenStreetMap has the concept of [top-level tags](https://wiki.openstreetmap.org/wiki/Top-level_tag) which define the primary "type" of each feature. Heirloom relies heavily on top-level tags to make blanket assumptions about features without needing to worry too much about specific tag values. For example, only features with specific top-level tags are included in the tiles.

Certain top-level keys such as `emergency` and `indoor` are used as attribute tags by some mappers, like `emergency=designated` or `indoor=yes`. For performance and consistency, features with these tag values are NOT ignored as top-level tags, possibly resulting in unexpected behavior.

### Troll tags

For performance and consistency, tag values like `no` and `unknown` (e.g. `building=no` or `shop=unknown`) are NOT ignored anywhere in Heirloom. These are sometimes called [troll tags](https://wiki.openstreetmap.org/wiki/Trolltag) in OSM since they may be technically accurate but often break apps. As such, these tags can be deleted from OSM if they cause issues in Heirloom tiles.

### Areas as ways

OpenStreetMap does not have distinct "line" and "area" entities, only "ways". Open ways can be assumed to be lines, but closed ways (where the first and last nodes are the same) are ambiguous. Each data consumer, including Heirloom, has to figure out how to deal with closed ways based on tagging. Heirloom takes a very strict approach.

* "Explicit" lines
  * Open ways regardless of tagging
  * Closed ways tagged `area=no`
* "Explicit" areas
  * Closed ways tagged `area=yes`
  * Closed ways with any `building` tag (including `building=no` and `building=unknown`)

### Low zooms vs. high zooms

Zoom level 12 is a magic threshold in Heirloom tiles. At z < 12, most features are aggregated and highly filtered for berevity. At z >= 12, most features correspond directly to OSM entities and contain a large number of attribute tags.

### Coastlines

In OpenStreetMap, coastline features model the boundary between land and ocean. They are special since they are mapped simply as connected ways tagged [`natural=coastline`](https://wiki.openstreetmap.org/wiki/Tag:natural%3Dcoastline), but they are included in the tiles as aggregate oceans.

## Layers

Heirloom tiles have just three layers, one for each geometry type. Note that these do not correspond exactly to OSM entity types, and that the same feature may appear in multiple layers. Actual inclusion is dependent on tagging and zoom level.

### `area`

Features in the `area` layer correspond to:

* `type=multipolygon` and `type=boundary` relations
* Closed ways with certain tagging. A closed way is one where the first and last nodes are the same. An `area=yes` or `building` tag will always qualify a closed way to be in this layer, while an `area=no` tag will always disqualify. Open ways are never included in the `area` layer regardless of tags.
* Oceans aggregated from coastlines

### `line`

Features in the `line` layer correspond to:

* Open ways regardless of `area` or `building` tags
* Closed ways with certain tagging:
  * An `area=no` tag will always qualify a closed way to be in this layer, while an `area=yes` or `building` tag will always disqualify. The `area` tag has no effect on open ways.
* Member ways of `type=route` and `type=waterway` relations

### `point`

Features in the `point` layer correspond to:

* Nodes
* Closed ways that also appear in the `area` layer, represented at the [`ST_PointOnSurface`](https://postgis.net/docs/ST_PointOnSurface.html)
* `type=multipolygon` and `type=boundary` relations, represented at the node with the [`label`](https://wiki.openstreetmap.org/wiki/Role:label) role if any, otherwise at the `ST_PointOnSurface`
* `type=route` and `type=waterway` relations, represented at the location along the relation closest to the centerpoint of the relations's bounding box

Features in the `point` layer are filtered as so:

* Polygon features are always included if they are well visible in the tile but not so large that they contain the tile
* Node features, and polyons too small to be visible in the tile, are filtered by zoom:
  * At z < 12, only features with specific notable tags are included
  * At z >= 12, all features are included unless there are too many in the given tile. Features tagged with `name` or `wikidata` tag are considered more notable than those without and are included first.

## Aggregation, filtering, and simplification

The features in Heirloom tiles are intended to match the original OpenStreetMap data as closely as possible. However, a certain loss of resolution is required in ordered to limit the size of the tiles. This is tuned toward cartography and is intended to have a limited impact on mapmakers.

* Line and area geometries are simplified with a tolerance matching the resolution of the tile, meaning the results should look nearly invisible to the user. This is done without regard to topology.
* Lines and areas too small to be seen when rendered in a tile are discarded. Centerpoints for these features are generally discarded as well.
* At zoom levels lower than 10, line and area geometries are aggregated together based on the keys listed in [attribute_keys_low_zoom_line.txt](server/schema_data/attribute_keys_low_zoom_line.txt) and [attribute_keys_low_zoom_area.txt](server/schema_data/attribute_keys_low_zoom_area.txt). At zoom level 10 and higher, there is one feature per OSM feature (no aggregation).

## Cheat sheet

Top-level tag support:

| OSM key | `point` layer | `line` layer | `area` layer | Closed way implies area | Irregularities |
|---|---|---|---|---|---|
|`aerialway`          |✔︎|✔︎|✔︎|No |
|`aeroway`            |✔︎|✔︎|✔︎|No |
|`advertising`        |✔︎| |✔︎|Yes|
|`amenity`            |✔︎| |✔︎|Yes|
|`area:highway`       | | |✔︎|Yes|
|`barrier`            |✔︎|✔︎|✔︎|No |
|`boundary`           |✔︎|✔︎|✔︎|Yes| Only `boundary=protected_area/aboriginal_lands` appear in the `area` layer.
|`building`           |✔︎| |✔︎|Yes|
|`building:part`      | | |✔︎|Yes|
|`club`               |✔︎| |✔︎|Yes|
|`craft`              |✔︎| |✔︎|Yes|
|`education`          |✔︎| |✔︎|Yes|
|`emergency`          |✔︎| |✔︎|Yes|
|`golf`               |✔︎|✔︎|✔︎|Yes|
|`healthcare`         |✔︎| |✔︎|Yes|
|`highway`            |✔︎|✔︎|✔︎|No |
|`historic`           |✔︎| |✔︎|Yes|
|`indoor`             |✔︎|✔︎|✔︎|Yes|
|`information`        |✔︎| |✔︎|Yes|
|`landuse`            |✔︎| |✔︎|Yes|
|`leisure`            |✔︎| |✔︎|Yes|
|`man_made`           |✔︎|✔︎|✔︎|Yes|
|`military`           |✔︎| |✔︎|Yes|
|`natural`            |✔︎|✔︎|✔︎|Yes| `natural=coastline` features are included in the `area` layer as aggregate oceans with no other attributes.
|`office`             |✔︎| |✔︎|Yes|
|`place`              |✔︎| | |Yes|
|`playground`         |✔︎| |✔︎|Yes|
|`power`              |✔︎|✔︎|✔︎|No |
|`public_transport`   |✔︎| |✔︎|Yes|
|`railway`            |✔︎|✔︎|✔︎|No |
|`route`              | |✔︎| |No |
|`shop`               |✔︎| |✔︎|Yes|
|`telecom`            |✔︎|✔︎|✔︎|No |
|`tourism`            |✔︎| |✔︎|Yes|
|`waterway`           |✔︎|✔︎|✔︎|No |
