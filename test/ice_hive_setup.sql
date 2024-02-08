use hive_prod;
create database nyc;
use nyc;
select current_catalog(), current_database();
show tables;
drop table if exists taxis;
CREATE TABLE taxis
(
  vendor_id bigint,
  trip_id bigint,
  trip_distance float,
  fare_amount double,
  store_and_fwd_flag string
)
PARTITIONED BY (vendor_id);
desc formatted taxis;

INSERT INTO taxis
VALUES (1, 1000371, 1.8, 15.32, 'N'), (2, 1000372, 2.5, 22.15, 'N'), (2, 1000373, 0.9, 9.01, 'N'), (1, 1000374, 8.4, 42.13, 'Y');
SELECT * FROM taxis;

desc formatted hive_prod.nyc.taxis;
select * from hive_prod.nyc.taxis;