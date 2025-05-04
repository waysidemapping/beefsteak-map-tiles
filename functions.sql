CREATE OR REPLACE
    FUNCTION function_get_rustic_tile(z integer, x integer, y integer)
    RETURNS bytea AS $$
DECLARE
  mvt bytea;
BEGIN
  RETURN
    COALESCE((
      SELECT ST_AsMVT(tile, 'barrier', 4096, 'geom') FROM (
        SELECT {{COLUMN_NAMES}}, "geom_type", ST_AsMVTGeom(geom, ST_TileEnvelope(z, x, y), 4096, 64, true) AS geom
        FROM "barrier"
        WHERE geom && ST_TileEnvelope(z, x, y)
          AND z >= 13
      ) as tile WHERE geom IS NOT NULL
    ), '') ||
    COALESCE((
      SELECT ST_AsMVT(tile, 'building', 4096, 'geom') FROM (
        SELECT {{COLUMN_NAMES}}, "geom_type", ST_AsMVTGeom(geom, ST_TileEnvelope(z, x, y), 4096, 64, true) AS geom
        FROM "building"
        WHERE geom && ST_TileEnvelope(z, x, y)
          AND z >= 13
      ) as tile WHERE geom IS NOT NULL
    ), '') ||
    COALESCE((
      SELECT ST_AsMVT(tile, 'highway', 4096, 'geom') FROM (
        SELECT {{COLUMN_NAMES}}, "geom_type", ST_AsMVTGeom(geom, ST_TileEnvelope(z, x, y), 4096, 64, true) AS geom
        FROM "highway"
        WHERE geom && ST_TileEnvelope(z, x, y)
          AND (
            (z >= 4 AND ("highway" IN ('motorway', 'motorway_link') OR "expressway" = 'yes'))
            OR (z >= 6 AND ("highway" IN ('trunk', 'trunk_link')))
            OR (z >= 10 AND ("highway" IN ('primary', 'primary_link', 'unclassified')))
            OR (z >= 11 AND ("highway" IN ('secondary', 'secondary_link')))
            OR (z >= 12 AND ("highway" IN ('tertiary', 'tertiary_link', 'residential')))
            OR z >= 13
          )
      ) as tile WHERE geom IS NOT NULL
    ), '') ||
    COALESCE((
      SELECT ST_AsMVT(tile, 'natural', 4096, 'geom') FROM (
        SELECT {{COLUMN_NAMES}}, "geom_type", ST_AsMVTGeom(geom, ST_TileEnvelope(z, x, y), 4096, 64, true) AS geom
        FROM "natural"
        WHERE geom && ST_TileEnvelope(z, x, y)
          AND (
            (z >= 0 AND ("natural" = 'water'))
            OR z >= 10
          )
      ) as tile WHERE geom IS NOT NULL
    ), '') ||
    COALESCE((
      SELECT ST_AsMVT(tile, 'railway', 4096, 'geom') FROM (
        SELECT {{COLUMN_NAMES}}, "geom_type", ST_AsMVTGeom(geom, ST_TileEnvelope(z, x, y), 4096, 64, true) AS geom
        FROM "railway"
        WHERE geom && ST_TileEnvelope(z, x, y)
          AND ("railway" != 'abandoned')
          AND (
            (z >= 4 AND ("railway" = 'rail' AND "service" IS NULL))
            OR (z >= 10 AND ("service" IS NULL))
            OR z >= 13
          )
      ) as tile WHERE geom IS NOT NULL
    ), '') ||
    COALESCE((
      SELECT ST_AsMVT(tile, 'waterway', 4096, 'geom') FROM (
        SELECT {{COLUMN_NAMES}}, "geom_type", ST_AsMVTGeom(geom, ST_TileEnvelope(z, x, y), 4096, 64, true) AS geom
        FROM "waterway"
        WHERE geom && ST_TileEnvelope(z, x, y)
          AND (
            (z >= 6 AND ("waterway" = 'river'))
            OR z >= 10
          )
      ) as tile WHERE geom IS NOT NULL
    ), '');
END
$$ LANGUAGE plpgsql IMMUTABLE STRICT PARALLEL SAFE;

DO $do$ BEGIN
    EXECUTE 'COMMENT ON FUNCTION function_get_rustic_tile IS $tj$' || $$
    {
        "description": "Delightfully unrefined OpenStreetMap tiles",
        "attribution": "© OpenStreetMap",
        "vector_layers": [
            {
              "id": "barrier"
            },
            {
              "id": "building"
            },
            {
              "id": "highway"
            },
            {
              "id": "natural"
            },
            {
              "id": "railway"
            },
            {
              "id": "waterway"
            }
        ]
    }
    $$::json || '$tj$';
END $do$;