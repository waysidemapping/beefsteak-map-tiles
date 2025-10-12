# Heirloom map tile schema

*This schema is in active development and is not yet versioned. Users should expect that changes may occur at any time without notice.*

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

## Concepts

### Top-level tags

OpenStreetMap has the concept of [top-level tags](https://wiki.openstreetmap.org/wiki/Top-level_tag) which define the primary "type" of each feature. Heirloom relies heavily on top-level tags to make blanket assumptions about features without needing to worry too much about specific tag values. For example, only features with specific top-level tags are included in the tiles.

### Troll tags

For performance and consistency, top-level tag values like `no` and `unknown` (e.g. `building=no` or `shop=unknown`) are NOT ignored anywhere in Heirloom. These are sometimes called [troll tags](https://wiki.openstreetmap.org/wiki/Trolltag) in OSM since they may be technically accurate but often break apps. As such, these tags can be deleted from OSM if they cause issues in Heirloom tiles.

Similarly, certain top-level keys such as `emergency` and `indoor` are used as attribute tags by some mappers, like `emergency=designated`. Again, for performance and consistency, features with these tag values are NOT ignored and may cause unexpected behavior.

### Areas as ways

For better or worse, OpenStreetMap does not have distinct "line" and "area" entities, only "ways". Open ways can be assumed to be lines, but closed ways (where the first and last nodes are the same) are ambiguous. Each data consumer, including Heirloom, has to figure out how to deal with closed ways based on tagging. Heirloom takes a very strict approach.

* "Explicit" lines
** Open ways regardless of tagging
** Closed ways tagged `area=no`
* "Explicit" areas
** Closed ways tagged `area=yes`
** Closed ways with any `building` tag (including `building=no` and `building=unknown`)

## Layers

Heirloom tiles have just three layers, one for each geometry type. Note that these do not correspond exactly to OSM entity types, and that the same feature may appear in multiple layers. Actual inclusion is dependent on tagging and zoom level.

### `area`

Features in the `area` layer correspond to `type=multipolygon` relations, `type=boundary` relations, or closed ways with certain tagging. A closed way is one where the first and last nodes are the same. An `area=yes` or `building` tag will always qualify a closed way to be in this layer, while an `area=no` tag will always disqualify. Open ways are never included in the `area` layer regardless of tags.

### `line`

Features in the `line` layer correspond to:

* Open ways regardless of `area` or `building` tags
* Closed ways with certain tagging:
** An `area=no` tag will always qualify a closed way to be in this layer, while an `area=yes` or `building` tag will always disqualify. The `area` tag has no effect on open ways.

### `point`

Features in the `point` layer correspond to:

* Nodes
* Closed ways that also appear in the `area` layer, represented at the [`ST_PointOnSurface`](https://postgis.net/docs/ST_PointOnSurface.html)
* `type=multipolygon` and `type=boundary` relations, represented at the node with the [`label`](https://wiki.openstreetmap.org/wiki/Role:label) role if any, otherwise at the `ST_PointOnSurface`
* `type=route` relations, represented at the location along the route closest to the centerpoint of the route's bounding box

Features in the `point` layer are filtered as so:

* Polygon features are always included if they are visible in the tile but not so large that they contain the tile
* Node features, and polyon too small to be visible in the tile, are filtered by zoom:
** At z < 12, only features with specific notable tags are included
** At z >= 12, all features with a `name` or `wikidata` tag are included
** At z >= 15, all features are included

## Coastlines

In OpenStreetMap, coastline features model the boundary between land and ocean. They require special treatment since they are mapped simply as connected ways tagged `natural=coastline` but we want to render them as areas.

## Aggregation, filtering, and simplification

The features in Heirloom tiles are intended to match the original OpenStreetMap data as closely as possible. However, a certain loss of resolution is required in ordered to limit the size of the tiles. This is tuned toward cartography and is intended to have a limited impact on mapmakers.

- Line and area geometries are simplified with a tolerance matching the resolution of the tile, meaning the results should look nearly invisible to the user. This is done without regard to topology.
- Lines and areas too small to be seen when rendered in a tile are discarded. Centerpoints for these features are generally discarded as well.
- At zoom levels lower than 10, line and area geometries are aggregated together based on the keys listed in [attribute_keys_low_zoom_line.txt](server/schema_data/attribute_keys_low_zoom_line.txt) and [attribute_keys_low_zoom_area.txt](server/schema_data/attribute_keys_low_zoom_area.txt). At zoom level 10 and higher, there is one feature per OSM feature (no aggregation).