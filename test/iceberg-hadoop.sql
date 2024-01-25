create database db;
create table db.iceberg_hadoop_table(
  vendor_id bigint,
  trip_id bigint,
  trip_distance float,
  fare_amount double,
  store_and_fwd_flag string
);
set @@sync_job=true;

-- test hard copy
load data infile 'iceberg://hadoop_prod.nyc.taxis2' into table db.iceberg_hadoop_table options(mode='overwrite'); -- offline
desc db.iceberg_hadoop_table;
select * from db.iceberg_hadoop_table;

-- test write out, can't create iceberg table taxis_out here, create it by spark with iceberg hadoop
select * from db.iceberg_hadoop_table into outfile 'iceberg://hadoop_prod.nyc.taxis_out2' options(mode='overwrite');

-- test multi soft copy, iceberg fmt can't append to table with hard data(parquet), so we need to overwrite
load data infile 'iceberg://hadoop_prod.nyc.taxis_out2' into table db.iceberg_hadoop_table options(mode='overwrite', deep_copy=false);
load data infile 'iceberg://hadoop_prod.nyc.taxis2' into table db.iceberg_hadoop_table options(mode='append', deep_copy=false);
desc db.iceberg_hadoop_table;
select * from db.iceberg_hadoop_table;

set @@execute_mode='online';
load data infile 'iceberg://hadoop_prod.nyc.taxis2' into table db.iceberg_hadoop_table options(mode='append');
select * from db.iceberg_hadoop_table;
