create database db;
create table db.iceberg_hive_table(
  vendor_id bigint,
  trip_id bigint,
  trip_distance float,
  fare_amount double,
  store_and_fwd_flag string
);
set @@sync_job=true;

load data infile 'iceberg://hive_prod.nyc.taxis' into table db.iceberg_hive_table options(mode='overwrite', sql='select * from hive_prod.nyc.taxis where vendor_id=1'); -- offline
desc db.iceberg_hive_table;
select * from db.iceberg_hive_table;

-- can't create table taxis_out here, create it by hive(spark with iceberg can't create table)
select * from db.iceberg_hive_table into outfile 'iceberg://hive_prod.nyc.taxis_out' options(mode='overwrite');
-- iceberg fmt can't append to table with hard data(parquet), so we need to overwrite
load data infile 'iceberg://hive_prod.nyc.taxis_out' into table db.iceberg_hive_table options(mode='overwrite', deep_copy=false);
load data infile 'iceberg://hive_prod.nyc.taxis' into table db.iceberg_hive_table options(mode='append', deep_copy=false);
desc db.iceberg_hive_table;
select * from db.iceberg_hive_table;

set @@execute_mode='online';
load data infile 'iceberg://hive_prod.nyc.taxis' into table db.iceberg_hive_table options(mode='append');
select * from db.iceberg_hive_table;
