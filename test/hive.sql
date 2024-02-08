-- use hive bulti-in catalog
CREATE DATABASE IF NOT EXISTS basic_test;
USE basic_test;
CREATE TABLE IF NOT EXISTS kv_table_hive (key INT, value STRING);
TRUNCATE TABLE kv_table_hive;
SET @@sync_job=true;
-- deep copy
LOAD DATA INFILE 'hive://basic_test.test' INTO TABLE kv_table_hive OPTIONS(mode='overwrite');
DESC kv_table_hive;
SELECT * FROM kv_table_hive;
LOAD DATA INFILE 'basic_test.test' INTO TABLE kv_table_hive OPTIONS(deep_copy=false, mode='overwrite', format='hive');
DESC kv_table_hive;
SELECT * FROM kv_table_hive;
SELECT * FROM kv_table_hive INTO OUTFILE 'hive://basic_test.openmldb_write' OPTIONS(mode='overwrite');
SET @@execute_mode='online';
-- truncate has already been executed, online table is empty
SHOW TABLE STATUS;
LOAD DATA INFILE 'hive://basic_test.test' INTO TABLE kv_table_hive OPTIONS(mode='append');
SELECT * FROM kv_table_hive;