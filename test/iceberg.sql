create database db;
create table db.t1(
  trip_id bigint,
  trip_distance float,
  fare_amount double,
  store_and_fwd_flag string,
  vendor_id bigint
);

set @@sync_job=true;
load data infile 'iceberg://hive_prod.nyc.taxis' into table db.t1 options(mode='overwrite'); -- offline
select * from db.t1;

-- can't create table taxis_out here, create it by hive(spark with iceberg can't create table)
select * from db.t1 into outfile 'iceberg://hive_prod.nyc.taxis_out' options(mode='overwrite');
-- iceberg fmt can't append to table with hard data(parquet), so we need to overwrite
load data infile 'iceberg://hive_prod.nyc.taxis_out' into table db.t1 options(mode='overwrite', deep_copy=false);
load data infile 'iceberg://hive_prod.nyc.taxis' into table db.t1 options(mode='append', deep_copy=false);
desc db.t1;
select * from db.t1;

set @@execute_mode='online';
load data infile 'iceberg://hive_prod.nyc.taxis' into table db.t1 options(mode='append');
select * from db.t1;
