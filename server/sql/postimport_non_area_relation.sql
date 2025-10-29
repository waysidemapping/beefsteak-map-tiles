
UPDATE non_area_relation
SET bbox_centerpoint_on_surface = ST_ClosestPoint(geom, ST_Centroid(bbox))
WHERE bbox_centerpoint_on_surface IS NULL;

UPDATE non_area_relation
SET bbox_centerpoint_on_surface_z26_tile_x = floor((ST_X(bbox_centerpoint_on_surface) + 20037508.3427892) / (40075016.6855784 / (1 << 26))),
    bbox_centerpoint_on_surface_z26_tile_y = floor((20037508.3427892 - ST_Y(bbox_centerpoint_on_surface)) / (40075016.6855784 / (1 << 26)))
WHERE bbox_centerpoint_on_surface_z26_tile_x IS NULL;
