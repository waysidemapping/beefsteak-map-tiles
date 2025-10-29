
UPDATE area_relation r
SET label_point = n.geom
FROM node n
WHERE n.id = r.label_node_id
    AND r.label_point IS NULL;

UPDATE area_relation
SET label_point = ST_PointOnSurface(geom)
WHERE label_point IS NULL;

UPDATE area_relation
SET label_point_z26_tile_x = floor((ST_X(label_point) + 20037508.3427892) / (40075016.6855784 / (1 << 26))),
    label_point_z26_tile_y = floor((20037508.3427892 - ST_Y(label_point)) / (40075016.6855784 / (1 << 26)))
WHERE label_point_z26_tile_x IS NULL;