create database if not exists db;
use db;
create table hive_acid_table like HIVE 'hive://basic_test.acid';
desc db.hive_acid_table;