UPDATE area_relation r
SET
  label_point = n.geom,
  label_point_z26_x = n.z26_x,
  label_point_z26_y = n.z26_y
FROM node n
WHERE
  r.label_point IS NULL
  AND n.id = r.label_node_id;
