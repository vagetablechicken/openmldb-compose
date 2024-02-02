-- delete all function to release so in memory
DROP FUNCTION cut2;
DROP FUNCTION strlength;
DROP FUNCTION third;
DROP FUNCTION first_ge;
CREATE FUNCTION cut2(x STRING) RETURNS STRING OPTIONS (FILE='libtest_udf.so');
CREATE FUNCTION strlength(x STRING) RETURNS INT OPTIONS (FILE='libtest_udf.so');
CREATE AGGREGATE FUNCTION third(x BIGINT) RETURNS BIGINT OPTIONS (FILE='libtest_udf.so', ARG_NULLABLE=true, RETURN_NULLABLE=true);
CREATE AGGREGATE FUNCTION first_ge(x BIGINT, threshold BIGINT) RETURNS BIGINT OPTIONS (FILE='libtest_udf.so', ARG_NULLABLE=true, RETURN_NULLABLE=true);
create database db;
use db;
create table t1 (s1 string, i1 bigint);
set @@execute_mode='online';
insert into t1 values ('abc', 1), ('abc', 2);
select cut2(s1) from t1;
select strlength(s1) from t1;
select *, first_ge(i1, bigint(2)) over w from t1 window w as (partition by s1 order by i1 rows between unbounded preceding and 0 preceding);
select *, first_ge(i1, bigint(NULL)) over w from t1 window w as (partition by s1 order by i1 rows between unbounded preceding and 0 preceding);
select *, first_ge(i1, i1) over w from t1 window w as (partition by s1 order by i1 rows between unbounded preceding and 0 preceding);