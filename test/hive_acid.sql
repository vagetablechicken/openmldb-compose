-- this script will failed cuz hive acid table is not supported in spark 3.2.1
CREATE DATABASE IF NOT EXISTS basic_test;
USE basic_test;
CREATE TABLE IF NOT EXISTS kv_table_hive_acid (key INT, value STRING);
TRUNCATE TABLE kv_table_hive_acid;
SET @@sync_job=true;
-- deep copy. select empty cuz hive acid, still load
LOAD DATA INFILE 'hive://basic_test.acid' INTO TABLE kv_table_hive_acid OPTIONS(mode='overwrite');
DESC kv_table_hive_acid;
-- select empty
SELECT * FROM kv_table_hive_acid;

LOAD DATA INFILE 'hive://basic_test.insert_only' INTO TABLE kv_table_hive_acid OPTIONS(mode='overwrite');
DESC kv_table_hive_acid;
-- select empty
SELECT * FROM kv_table_hive_acid;

LOAD DATA INFILE 'hive://basic_test.acid_bucketed' INTO TABLE kv_table_hive_acid OPTIONS(mode='overwrite');
DESC kv_table_hive_acid;
-- select empty
SELECT * FROM kv_table_hive_acid;

LOAD DATA INFILE 'hive://basic_test.insert_only_bucketed' INTO TABLE kv_table_hive_acid OPTIONS(mode='overwrite');
DESC kv_table_hive_acid;
-- select empty
SELECT * FROM kv_table_hive_acid;