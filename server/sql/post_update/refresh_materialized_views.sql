-- concurrently avoids locking out other queries during the refresh
REFRESH MATERIALIZED VIEW CONCURRENTLY way_relation_combined;