
SET work_mem = '512MB';
WITH to_update AS (
  SELECT
    id,
    ST_PointOnSurface(geom) AS centerpoint
  FROM way_no_explicit_geometry_type
  WHERE label_point IS NULL
)
UPDATE way_no_explicit_geometry_type w
SET
  label_point = centerpoint,
  label_point_z26_x = floor((ST_X(centerpoint) + 20037508.3427892) / (40075016.6855784 / (1 << 26))),
  label_point_z26_y = floor((20037508.3427892 - ST_Y(centerpoint)) / (40075016.6855784 / (1 << 26)))
FROM to_update u
WHERE w.id = u.id AND centerpoint IS NOT NULL;
RESET work_mem;
