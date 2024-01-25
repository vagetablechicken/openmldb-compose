show components;
set @@sync_job=true;
create database db;
create table db.hdfs_test(Name string, Age bigint);
set @@execute_mode='online';
load data infile 'hdfs://namenode:19000/user/test/df.parquet' into table db.hdfs_test  options(format='parquet',mode='append');
select * from db.hdfs_test;
