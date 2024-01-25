create database db;
create table db.iceberg_rest_table(
  vendor_id bigint,
  trip_id bigint,
  trip_distance float,
  fare_amount double,
  store_and_fwd_flag string
);
set @@sync_job=true;

-- iceberg rest (hive catalog -> rest)
-- test hard copy
load data infile 'iceberg://rest_prod.nyc.taxis' into table db.iceberg_rest_table options(mode='overwrite'); -- offline
desc db.iceberg_rest_table;
select * from db.iceberg_rest_table;

-- test write out, the table taxis_out is created by hive when test hive catalog
select * from db.iceberg_rest_table into outfile 'iceberg://rest_prod.nyc.taxis_out' options(mode='overwrite');

-- test multi soft copy, iceberg fmt can't append to table with hard data(parquet), so we need to overwrite
load data infile 'iceberg://rest_prod.nyc.taxis_out' into table db.iceberg_rest_table options(mode='overwrite', deep_copy=false);
load data infile 'iceberg://rest_prod.nyc.taxis' into table db.iceberg_rest_table options(mode='append', deep_copy=false);
desc db.iceberg_rest_table;
select * from db.iceberg_rest_table;

set @@execute_mode='online';
load data infile 'iceberg://rest_prod.nyc.taxis' into table db.iceberg_rest_table options(mode='append');
select * from db.iceberg_rest_table;
