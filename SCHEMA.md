# Heirloom map tile schema

This schema is in active development and is not yet versioned. Users should expect that changes may occur at any time without notice.

## Layers

Heirloom tiles have just three layers, one for each geometry type. Note that these do not correspond exactly to OSM entity types, and that the same feature may appear in multiple layers. Actual inclusion is dependent on tagging and zoom level.

### `area`

Features in the `area` layer correspond to `type=multipolygon` relations, `type=boundary` relations, or closed ways with certain tagging. A closed way is one where the first and last nodes are the same. An `area=yes` or `building` tag will always qualify a closed way to be in this layer, while an `area=no` tag will always disqualify. Open ways are never included in the `area` layer regardless of tags.

### `line`

Features in the `line` layer correspond to open ways, or closed ways with certain tagging. An `area=no` tag will always qualify a closed way to be in this layer, while an `area=yes` or `building` tag will always disqualify. The `area` tag has no effect on open ways.

### `point`

Features in the `point` layer correspond to tagged nodes, or the centerpoints of areas (usually the [pole of inaccessbility](https://en.wikipedia.org/wiki/Pole_of_inaccessibility#Methods_of_calculation)). Features that would appear in the `line` layer are not represented in the `point` layer.

## Top-level tags

OpenStreetMap has the concept of [top-level tags](https://wiki.openstreetmap.org/wiki/Top-level_tag) which define the main type of each feature. Heirloom tiles include only features tagged with a supported top-level tag. Each tag has specific geometry expectations.

For performance and consistency, features with the top-level tag values `no` and `unknown` (e.g. `building=no` or `shop=unknown`) are NOT ignored. These are sometimes called [troll tags](https://wiki.openstreetmap.org/wiki/Trolltag) in OSM since they may be technically accurate but often break apps. As such, these tags can be deleted from OSM if they cause issues in Heirloom tiles.

Similarly, certain top-level keys such as `emergency` and `indoor` are used as attribute tags by some mappers, like `emergency=designated`. Again, for performance and consistency, features with these tag values are NOT ignored and may cause unexpected behavior.

| OSM key | `point` layer | `line` layer | `area` layer | Closed way implies area | Irregularities |
|---|---|---|---|---|---|
|`aerialway`          |✔︎|✔︎|✔︎|No |
|`aeroway`            |✔︎|✔︎|✔︎|No |
|`advertising`        |✔︎| |✔︎|Yes|
|`amenity`            |✔︎| |✔︎|Yes|
|`area:highway`       | | |✔︎|Yes|
|`barrier`            |✔︎|✔︎|✔︎|No |
|`boundary`           |✔︎| |✔︎|Yes| Only `boundary=protected_area/aboriginal_lands` are supported at this time.
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

### Unsupported tags

The following keys are often considered top-level tags in OSM but are not supported as such in the tiles at this time.

* `allotments`
* `attraction`
* `bridge:support`
* `cemetery`
* `entrance`
* `ford`
* `junction`
* `landcover`
* `noexit`
* `piste:type`
* `roller_coaster`
* `traffic_calming`
* `traffic_sign`
