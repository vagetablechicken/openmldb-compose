-- data is in hdfs://namenode:9000/tmp/shell-out
CREATE DATABASE IF NOT EXISTS basic_test;
USE basic_test;
CREATE TABLE IF NOT EXISTS kv_table (key INT, value STRING);
TRUNCATE TABLE kv_table;
SET @@sync_job=true;
-- deep copy
LOAD DATA INFILE 'hdfs://namenode:9000/tmp/shell-out' INTO TABLE kv_table OPTIONS(mode='overwrite');
DESC kv_table;
SELECT * FROM kv_table;
LOAD DATA INFILE 'hdfs://namenode:9000/tmp/shell-out' INTO TABLE kv_table OPTIONS(deep_copy=false, mode='overwrite');
DESC kv_table;
SELECT * FROM kv_table;
SELECT * FROM kv_table INTO OUTFILE 'hdfs://namenode:9000/tmp/openmldb-out' OPTIONS(mode='overwrite');
SET @@execute_mode='online';
-- truncate has already been executed, online table is empty
SHOW TABLE STATUS;
LOAD DATA INFILE 'hdfs://namenode:9000/tmp/shell-out' INTO TABLE kv_table OPTIONS(mode='append');
SELECT * FROM kv_table;