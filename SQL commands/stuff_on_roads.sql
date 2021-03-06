﻿--Original provided by PT
drop table if exists sandbox.foo;
create table sandbox.foo as with roads as (select st_transform(geom, 26910) geom from biomass."MdfTransportation" line 
	union select st_transform(geom, 26910) geom
	from sandbox.maj_road_test) select st_setsrid((st_dumppoints(st_simplify(st_union(geom), 1000))).geom, 26910) geom from roads;

alter table biomass.foo add column gid serial primary key;


-- version implemented in the test
drop table if exists sandbox.foo;
create table sandbox.foo as with roads as (select st_transform(geom, 26910) geom from biomass."MdfTransportation" line 
	union select st_transform(the_geom, 26910) geom
	from sandbox.maj_road_test) select st_setsrid((st_dumppoints(st_simplify(st_union(geom), 1000))).geom, 26910) geom from roads;

alter table sandbox.foo add column gid serial primary key;

-- NN using the Dt_distance method 

SET search_path to sandbox, public;
SELECT DISTINCT ON(gref_gid) g1.id As gref_gid, 
g2.gid As gnn_gid, ST_Distance(st_transform(g1.geom,26910),st_transform(g2.geom,26910))  as distance, 
    FROM biosum_test As g1, foo As g2  
WHERE g1.id = 2149 and g1.id <> g2.gid  AND ST_DWithin(st_transform(g1.geom,26910), st_transform(g2.geom,26910), 1900)  
ORDER BY gref_gid, ST_Distance(st_transform(g1.geom,26910),st_transform(g2.geom,26910)) 
LIMIT 5

SET search_path to sandbox, public;
SELECT DISTINCT ON(gref_gid) g1.id As gref_gid, 
g2.gid As gnn_gid, ST_Distance(st_transform(g1.geom,26910),st_transform(g2.geom,26910))  as distance 
    FROM biosum_test As g1, foo As g2  
WHERE g1.id = 2149 and g1.id <> g2.gid  AND ST_DWithin(st_transform(g1.geom,26910), st_transform(g2.geom,26910), 1900)  
ORDER BY gref_gid, st_transform(g1.geom,26910) <-> st_transform(g2.geom,26910)
LIMIT 5

SELECT g1.gid, g1.description, nn.gid As nn_gid, nn.description As nn_description, distance(nn.the_g
eom,g1.the_geom) as dist
FROM (SELECT * FROM sometable ORDER BY gid LIMIT 100) g1 CROSS APPLY 
    (SELECT g2.*  
        FROM sometable As g2 
        WHERE g1.gid <> g2.gid AND expand(g1.the_geom, 300) && g2.the_geom)  
ORDER BY distance(g2.the_geom, g1.the_geom) LIMIT 5) As nn 

ORDER BY biosum_test.geom <-> st_transform((select geom from foo where id = 3319),26910)

SELECT DISTINCT ON(gref_gid) g1.id As gref_gid, 
g2.gid As gnn_gid, ST_Distance(st_transform(g1.geom,26910),st_transform(g2.geom,26910))  as distance 
    FROM biosum_test As g1, foo cross APPLY (
    select g2.* from foo as g2   
WHERE g1.id and g1.id <> g2.gid  AND ST_DWithin(st_transform(g1.geom,26910), st_transform(g2.geom,26910), 1900)  
ORDER BY gref_gid, st_transform(g1.geom,26910) <-> st_transform(g2.geom,26910)

-- Proper query for one of the id in the tables. 

SET search_path to sandbox, public;
SELECT DISTINCT ON(biomass_id) g1.id As biomass_id, 
g2.gid As road_id, ST_Distance(st_transform(g1.geom,26910),st_transform(g2.geom,26910)) as distance 
    FROM biosum_test As g1, foo As g2  
WHERE g1.id = 2149 and g1.id <> g2.gid  AND ST_DWithin(st_transform(g1.geom,26910), st_transform(g2.geom,26910), 1900)  
ORDER BY biomass_id, st_transform(g1.geom,26910) <-> st_transform(g2.geom,26910)

http://geeohspatial.blogspot.com/2013/05/k-nearest-neighbor-search-in-postgis.html

-- Final version 

SET search_path to sandbox, public;
SELECT DISTINCT ON(biomass_id) g1.id As biomass_id, 
g2.gid As road_id, ST_Distance(st_transform(g1.geom,26910),st_transform(g2.geom,26910)) as distance 
    FROM biosum_test As g1, foo As g2  
WHERE 
--	g1.id = 2149 and 
--	g1.id <> g2.gid  AND 
	ST_DWithin(st_transform(g1.geom,26910), st_transform(g2.geom,26910), 1000)  
ORDER BY biomass_id, st_transform(g1.geom,26910) <-> st_transform(g2.geom,26910)

-- Kmeans code that reflects the number of points in the cluster

SET search_path to sandbox, public;
SELECT kmeans, count(*), ST_Centroid(ST_Collect(geom)) AS geom
FROM (
  SELECT kmeans(ARRAY[lon, lat], 5) OVER (), geom
  FROM biosum_test
) AS ksub
GROUP BY kmeans
ORDER BY kmeans;

-- Kmeans code that reflects the total yield from in the cluster

SET search_path to sandbox, public;
SELECT kmeans, count(*), sum(chip_yield) as yield, ST_Centroid(ST_Collect(geom)) AS geom
FROM (
  SELECT kmeans(ARRAY[lon, lat], 10) OVER (), geom, chip_yield
  FROM biosum_test
) AS ksub
GROUP BY kmeans
ORDER BY kmeans;

-- Cluster within code 

drop table if exists sandbox.foo2;
create table sandbox.foo2 as
SELECT row_number() over () AS id, ST_NumGeometries(gc) as total_number,
  st_setsrid(ST_MinimumBoundingCircle(gc),26910) as geom
FROM (
  SELECT unnest(ST_ClusterWithin(st_transform(geom,26910), 6000)) as gc
  FROM sandbox.biosum_test
) f;

-- Cluster kmeans using circle

drop table if exists sandbox.kmeans2;
create table sandbox.kmeans2 as
SELECT kmeans, count(*), sum(chip_yield) as yield, st_setsrid(ST_MinimumBoundingCircle(ST_Collect(geom)),4326)
 AS geom
FROM (
  SELECT kmeans(ARRAY[lon, lat], 10) OVER (), geom, chip_yield
  FROM sandbox.biosum_test
) AS ksub
GROUP BY kmeans
ORDER BY kmeans;

-- Failed stuff on roads

create table roads_data.ca_roads_osm as with ca as (select st_union(the_geom) geom from "General_GIS_DATA"."California_counties") select * from roads_data.roads_california r, ca c where st_intersects(c.geom,r.wkb_geometry);