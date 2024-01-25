create database db;
create table db.insert_fail(c1 int, c2 timestamp, c3 date, c4 string);
truncate table db.insert_fail;
set @@execute_mode='online';
set @@sync_job=true;
--insert into db.insert_fail values (1,1,"1970-01-01","ok"), (2,"invalid","","failed");
load data infile 'hdfs://namenode:19000/user/test/insert_fail.csv' into table db.insert_fail options(mode='append');
--load data infile '/work/test/csv_data/insert_fail.csv' into table  db.insert_fail options(mode='append', load_mode='local');
select * from db.insert_fail;
