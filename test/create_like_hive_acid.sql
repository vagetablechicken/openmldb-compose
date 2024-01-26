create database if not exists db;
use db;
create table hive_acid_table like HIVE 'hive://default.acid_table';
desc db.hive_acid_table;