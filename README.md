# 🍅 Heirloom Map Tiles

_Server-farm-to-table OpenStreetMap tiles_

Heirloom is a special cultivar of [OpenStreetMap](https://www.openstreetmap.org/about/)-based vector tiles developed for artisan mapmakers. While mass-market solutions like [OpenMapTiles](https://openmaptiles.org/) are great for building simple basemaps, they trade off data fidelity for ease-of-use. Heirloom instead contains the full palette of flavors found in OSM data—the sour along with the sweet—though they're still pruned for size. Heirloom even supports live updates from OSM to ensure the freshest maps possible. You can get it more easily from a can, but these are map tiles for people who make their own pasta sauce (and love to throw in a parmesan rind).

### 🍝 Features

- 🤌 **Pure OpenStreetMap**: OSM has all the vector data you need to make a great map. Patching in external datasets such as Natural Earth or Wikidata makes the map harder to deploy and more difficult to edit, so Heirloom doesn't bother.
- 🦆 **Tags are tags**: OSM mappers love the richness of OSM tagging and typically prefer to work with it directly. Heirloom does not make opinionated tag transforms or filter tag values, so new and niche values are supported automatically.
- 🔂 **Minutely updates**: Seeing your edits appear on the map right away makes mapping more fun. It also surfaces potential issues quickly before they are propagated elsewhere. Heirloom is able to pull in minutely diffs from the mainline OSM servers to keep the tiles as fresh as possible.
- 🌾 **High-zoom tiles**: Other tilesets render only low- and mid-zoom tiles, relying on "overzoom" to show detailed areas. Heirloom instead renders high-zoom tiles so that indoor floorplans, building parts, highway areas, and other micromapped features can be included without ballooning individual tile sizes.
- 🔌 **Hot-swappable schema**: OSM tagging standards are always changing and growing. Heirloom is future-proofed by handling most data logic at render time. This way, updates can be applied immediately without a planet-wide rebuild.

### ⚠️ Caveats

- 🏓 **Server required**: Heirloom requires a traditional tileserver to deliver features like minutely-updated tiles. This model generally has greater cost and complexity compared to static map tile solutions like [Planetiler](https://github.com/onthegomap/planetiler) + [Protomaps](https://protomaps.com/).
- 🍋 **No sugarcoating**: Heirloom presents the data as-is without trying to hide issues or assume too much knowledge about OSM tagging. This gives cartographers more power, but also increases styling complexity. And where OSM data is inconsistent or broken, Heirloom will be too.
- 🏋️ **Heavy tile sizes**: To support richer map styles, Heirloom includes a lot more data than found in traditional "production" map tiles. This can cause Heirloom-based maps to be less responsive over slower connections. Even so, these are not QA tiles and do not include all OSM features or tags.
- 🧐 **Built for a single renderer**: Heirloom tiles are tuned to look visually correct rendered as Web Mercator in [MapLibre](https://maplibre.org). They are not tested for other use cases. Data may not always be topologically correct.
- 🏝️ **No planet-level processing**: Database-wide functions, such as network analysis or coastline aggregation, are not performant for minutely-updated tiles. All processing in Heirloom is done per-feature at import or per-tile at render.

### 🧺 What's inside



### 🥫 Alternatives

Heirloom map tiles aren't for everyone. If you don't need Heirloom's power and complexity, consider working with something simpler.

If you don't need minutely updates, high-zoom tiles, or a hot-swappable schema, then you don't need to run a traditional tileserver. If you still want to work with raw OSM tags, I recommend checking out [Sourdough](https://sourdough.osm.fyi/) by [@jake-low](https://github.com/jake-low/). Heirloom and Sourdough are cousins of sorts.

If you just want an out-of-the-box solution with broad support you probably want [OpenMapTiles](https://openmaptiles.org/). There are a few free tileservers providing tiles in this format, mainly the [OSM US Tileservice](https://tiles.openstreetmap.us/) and [OpenFreeMap](https://openfreemap.org/).

If you're looking for a lean, general-purpose tile schema supported on openstreetmap.org, see [Shortbread](https://shortbread-tiles.org/).

## Development

### Stack

- [Martin](https://github.com/maplibre/martin): vector maptile server
- [osm2pgsql](https://github.com/osm2pgsql-dev/osm2pgsql): OSM data importer for Postgres
- [PostGIS](https://postgis.net): geospatial extension for Postgres
- [OpenStreetMap](https://www.openstreetmap.org/about/) (OSM): free, collaborative, global geospatial database 

### Schema

Heirloom uses a custom tile schema to achieve its design goals. See [SCHEMA.md](SCHEMA.md) for detailed info.

### Running locally

For convenience, a Dockerfile is provided that will run the server in an Ubuntu environment. Deploying the stack via Docker is intended for development only and has not been tested in production.

To build the reusable Docker image, run:

```
docker build -t rustic-tileserver:latest -f Dockerfile .
```

To create and start a container using the Docker image, run: 

```
docker run --name rustic-dev-container -p 3000:3000 --mount type=bind,src=./server,dst=/usr/src/app --mount type=bind,src=./tmp,dst=/var/tmp/app rustic-tileserver:latest
```

The first `--mount` is required to copy over the `/server` directory to the container. Any changes to these files will be immediately synced between the host and the container. The second `--mount` is optional but is convenient for managing intermediate files (which may be quite large) on the host system.

To restart the container once it's stopped, run:

```
docker start rustic-dev-container -i
```

To apply changes to `functions.sql` while the container (and Postgres) are running, run:

```
docker exec -i rustic-dev-container /usr/src/app/update_sql_functions.sh
```

To run a custom SQL query in the database (useful for debugging), run:

```
docker exec -i rustic-dev-container sudo -u postgres psql -U postgres -d osm -c "yourquery"
```