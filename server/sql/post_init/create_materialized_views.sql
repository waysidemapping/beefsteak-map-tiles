CREATE MATERIALIZED VIEW way_relation_combined AS
WITH rel AS (
  -- the area_ and non_area_ relation tables form a complete set of the relations we care about
    SELECT id, tags, extent, geom
    FROM area_relation
  UNION ALL
    SELECT id, tags, extent, geom
    FROM non_area_relation
)
SELECT
  w.id AS way_id,
  rw.relation_id AS relation_id,
  rw.member_role AS member_role,
  ANY_VALUE(w.geom) AS way_geom,
  ANY_VALUE(w.tags) AS way_tags,
  ANY_VALUE(r.tags) AS relation_tags,
  ANY_VALUE(r.extent) AS relation_extent
FROM way w
JOIN way_relation_member rw ON w.id = rw.member_id
JOIN rel r ON rw.relation_id = r.id
-- we only need one row per way/relation/role combo
GROUP BY w.id, rw.relation_id, rw.member_role;

-- a unique index is required in order to refresh concurrently
CREATE UNIQUE INDEX ON way_relation_combined USING btree (way_id, relation_id, member_role);
CREATE INDEX ON way_relation_combined USING btree (relation_id);
CREATE INDEX ON way_relation_combined USING btree (member_role);
CREATE INDEX ON way_relation_combined USING btree (relation_extent);
CREATE INDEX ON way_relation_combined USING gin (way_tags);
CREATE INDEX ON way_relation_combined USING gin (relation_tags);
CREATE INDEX ON way_relation_combined USING gist (way_geom);