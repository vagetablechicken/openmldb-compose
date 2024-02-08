create database if not exists db;
create table if not exists db.iceberg_hive_table(
  vendor_id bigint,
  trip_id bigint,
  trip_distance float,
  fare_amount double,
  store_and_fwd_flag string
);
truncate table db.iceberg_hive_table;
set @@sync_job=true;
-- so just 2 rows(id=1)
load data infile 'iceberg://hive_prod.nyc.taxis' into table db.iceberg_hive_table options(mode='overwrite', sql='select * from hive_prod.nyc.taxis where vendor_id=1');
desc db.iceberg_hive_table;
select * from db.iceberg_hive_table;
-- create a iceberg table taxis_out, write 2 rows
select * from db.iceberg_hive_table into outfile 'iceberg://hive_prod.nyc.taxis_out' options(mode='overwrite');
-- iceberg fmt can't append to table with hard data(parquet), so we need to overwrite
load data infile 'iceberg://hive_prod.nyc.taxis_out' into table db.iceberg_hive_table options(mode='overwrite', deep_copy=false);
load data infile 'iceberg://hive_prod.nyc.taxis' into table db.iceberg_hive_table options(mode='append', deep_copy=false);
desc db.iceberg_hive_table;
-- 6 rows
select * from db.iceberg_hive_table;

set @@execute_mode='online';
show table status like 'iceberg_hive_table';
load data infile 'iceberg://hive_prod.nyc.taxis' into table db.iceberg_hive_table options(mode='append');
-- 4 rows
select * from db.iceberg_hive_table;