# OpenMLDB Cluster

OpenMLDB with all components and hdfs service.

```
docker-compose build <service> # build image if you modify Dockerfile
docker-compose up -d
```

cleanup storage:
```
docker volume ls | grep openmldb-compose | awk '{print$2}' | xargs docker volume rm
```

## compose

If hdfs is localhost, tm container can't access it. So I create hdfs cluster by namenode, ... And I add hive as a service `metastore`.

OpenMLDB Spark should add iceberg jars, if version < 0.8.5. https://iceberg.apache.org/releases/. And spark need https://iceberg.apache.org/docs/latest/hive/ to use hive catalog. download iceberg-hive-runtime.
```
wget https://search.maven.org/remotecontent?filepath=org/apache/iceberg/iceberg-spark-runtime-3.2_2.12/1.4.3/iceberg-spark-runtime-3.2_2.12-1.4.3.jar
wget https://repo1.maven.org/maven2/org/apache/iceberg/iceberg-hive-runtime/1.4.3/iceberg-hive-runtime-1.4.3.jar
```

cp iceberg-hive-runtime-1.4.2.jar $SPARK_HOME/jars or add conf `spark.jars.packages=org.apache.iceberg:iceberg-spark-runtime-3.2_2.12:1.4.3;org.apache.iceberg:iceberg-hive-runtime:1.4.3`.

## test

test hdfs:
```
echo 'sc.parallelize(List( (1,"a"), (2,"b") )).toDF("key","value").write.mode("overwrite").option("header", "true").csv("hdfs://namenode:9000/tmp/shell-out")' | $SPARK_HOME/bin/spark-shell
```

then you can read:
```
echo 'spark.read.option("header", "true").csv("hdfs://namenode:19000/tmp/shell-out").show()' | $SPARK_HOME/bin/spark-shell
```

Debug hdfs:
TODO

Debug zk:
```
echo stat | nc openmldb-compose-zk-1 2181
```

To run openmldb test, scripts are in dir test/, run:
```
/work/openmldb/sbin/openmldb-cli.sh < test/test.sql
```
You can check it on hdfs:
echo 'spark.read.option("header", "true").csv("hdfs://namenode:19000/test/").show()' | $SPARK_HOME/bin/spark-shell


docker-compose2 --env-file compose.env -f hadoop-compose.yml -f hive-compose.yml -f compose.yml down -v --remove-orphans
docker-compose2 --env-file compose.env -f hadoop-compose.yml -f hive-compose.yml -f compose.yml up -d

### Hive official

I've tried https://github.com/apache/hive/blob/master/packaging/src/docker/docker-compose.yml set warehouse to hdfs path(not local path), and use postgres.
But hive will use `- warehouse:/opt/hive/data/warehouse` to store table, so it's not compatible with hdfs. Set hadoop conf core-site.xml in hadoop home, and hiveserver2 use the same confs.

docker-compose2 --env-file compose.env -f hadoop-compose.yml -f hive-compose.yml up -d

psql metastore_db -U hive

docker exec -it hiveserver2 beeline -u 'jdbc:hive2://hiveserver2:10000/'

### Hive Self Build(backup)

Build hive docker image by myself. see [Dockerfile](hive/Dockerfile).

https://dlcdn.apache.org/hadoop/common/hadoop-3.3.6/hadoop-3.3.6.tar.gz
https://dlcdn.apache.org/hive/hive-4.0.0-beta-1/apache-hive-4.0.0-beta-1-bin.tar.gz

Hive uses Hadoop, so you must have Hadoop in your path, so we must install hive in hadoop env(client side, connect to hdfs cluster)
```
export JAVA_HOME=/usr/lib/jvm/java-1.8.0-openjdk-1.8.0.242.b08-0.el7_7.x86_64/jre
export HADOOP_HOME=$(pwd)/hadoop-3.3.6
export HADOOP_CONF_DIR=$HADOOP_HOME/etc/hadoop
export HIVE_HOME=$(pwd)/apache-hive-4.0.0-beta-1-bin

cp core-site.xml $HADOOP_HOME/etc/hadoop
# /user/hive/warehouse (aka hive.metastore.warehouse.dir) 
$HADOOP_HOME/bin/hadoop fs -fs hdfs://localhost:19000 -mkdir       /tmp
$HADOOP_HOME/bin/hadoop fs -fs hdfs://localhost:19000 -mkdir -p      /user/hive/warehouse
$HADOOP_HOME/bin/hadoop fs -fs hdfs://localhost:19000 -chmod g+w   /tmp
$HADOOP_HOME/bin/hadoop fs -fs hdfs://localhost:19000 -chmod g+w   /user/hive/warehouse

derby sucks, use postgres.

Hive by default gets its configuration from <install-dir>/conf/hive-default.xml
The location of the Hive configuration directory can be changed by setting the HIVE_CONF_DIR environment variable.
Configuration variables can be changed by (re-)defining them in <install-dir>/conf/hive-site.xml.

cp hive-site.xml $HIVE_HOME/conf
$HIVE_HOME/bin/schematool -dbType postgres -initSchema --verbose

# hiveserver2 just for test, don't make it as a service
$HIVE_HOME/bin/hiveserver2 & # server
$HIVE_HOME/bin/beeline -u jdbc:hive2:// # cli on server
$HIVE_HOME/bin/beeline -u jdbc:hive2://metastore:10000 # cli on client

show databases; # one `default` db
```

spark-sql start way:
```
$SPARK_HOME/bin/spark-sql --properties-file test/spark.extra.ini -c spark.openmldb.sparksql=true
```

**We need hive-site.xml to read hive when we use spark, not only a metastore uri, so it should be in $HIVE_HOME(deploy-node), or copy hive-site.xml to spark conf dir(taskmanager containers).**

### compose description

You can do anything in deploy-node. In deploy-node, run hadoop or beeline, will use conf in $HADOOP_HOME or $HIVE_HOME.

Hadoop is simple, so you can access it just by url, like `hdfs://namenode:9000/`. So spark can access it without any hadoop config. `hadoop fs -fs hdfs://namenode:9000 ...` is ok.

Hive: if you use beeline, just need the url and the executable. `beeline -u jdbc:hive2://hiveserver2:10000/`. No extra conf is needed.

Spark will try to use hive to be built-in catalog, if has hive dependencies, even no hive conf, or set config `spark.sql.catalogImplementation=hive` forcelly.

Origin spark release of OpenMLDB test:
- has hive jars, even no available hive conf, hive catalog `INFO Main: Created Spark session with Hive support`.
- set `spark.sql.catalogImplementation=in-memory`, normal catalog `INFO Main: Created Spark session`.
- rm hive jars, `INFO Main: Created Spark session`.

**The logic is in `org.apache.spark.repl.Main.createSparkSession()`, so only spark-shell will use hive catalog by default when has hive jars. pyspark, spark-sql and spark-submit will use in-memory catalog by default.** TODO

#### OpenMLDB to hive

OpenMLDB Spark to hive needs hive conf, cuz it use metastore, not hiveserver2 jdbc. You can test by just run `spark-shell/spark-sql` with metastore uri arg.
OpenMLDB Spark doesn't have pyspark env, but I have installed pyspark in deploy-node. But pyspark 3.2.1 has some limitations, so I use spark-shell to test too.
```
echo spark.sessionState.catalog | $SPARK_HOME/bin/spark-shell -c spark.hadoop.hive.metastore.uris=thrift://metastore:9083

scala> spark.sessionState.catalog
res0: org.apache.spark.sql.catalyst.catalog.SessionCatalog = org.apache.spark.sql.hive.HiveSessionCatalog@3789bd95

python3 /work/test/pyspark-hive.py
```

```
24/02/02 07:38:53 INFO HiveConf: Found configuration file null
24/02/02 07:38:53 INFO HiveUtils: Initializing HiveMetastoreConnection version 2.3.9 using Spark classes.
24/02/02 07:38:53 INFO HiveClientImpl: Warehouse location for Hive client (version 2.3.9) is file:/work/test/spark-warehouse
24/02/02 07:38:53 INFO metastore: Trying to connect to metastore with URI thrift://metastore:9083
24/02/02 07:38:53 INFO metastore: Opened a connection to metastore, current connections: 1
24/02/02 07:38:53 INFO metastore: Connected to metastore.
```

`spark.hadoop.hive.metastore.uris` and `spark.hive.metastore.uris` both work. `spark.hadoop.hive.metastore.uris` is recommended?

Only have uris now, just see metadata, select(even no postgresql jar), but can't create table. If you want, you needs to config warehouse and more(just metastore.uris and warehouse can't work). For simplicity, I use hive-site.xml. Pyspark session can start without hive conf options, log shows it loads hive-site.xml in `$HIVE_HOME/conf`.

```
24/02/02 08:25:42 INFO HiveConf: Found configuration file file:/work/openmldb/spark-3.2.1-bin-openmldbspark/conf/hive-site.xml
24/02/02 08:25:42 INFO HiveUtils: Initializing HiveMetastoreConnection version 2.3.9 using Spark classes.
24/02/02 08:25:42 INFO HiveClientImpl: Warehouse location for Hive client (version 2.3.9) is hdfs://namenode:9000/user/hive/warehouse
24/02/02 08:25:42 INFO metastore: Trying to connect to metastore with URI thrift://metastore:9083
24/02/02 08:25:42 INFO metastore: Opened a connection to metastore, current connections: 1
24/02/02 08:25:42 INFO metastore: Connected to metastore.
```

**You can't create hive table with remote location in spark sql, `USING hive` only creates table in local warehouse(`pwd`/spark-warehouse). So I use dataframe save to create table.**

So when we have hive-site.xml and postgresql jar, Spark in anywhere can read and write hive in scala.

If we don't want hive session catalog to be built-in catalog, we can set `spark.sql.catalogImplementation=in-memory` to use in-memory catalog and disable rewrite in taskmanager by `enable.hive.support=false`. We shouldn't rm bind in compose, cuz iceberg hive catalog needs hive-site.xml too.

In compose, I set `enable.hive.support=false` in taskmanager, but spark have hive jars, so it still will be hive catalog by default(just to avoid debug on it). `--spark_conf` is the last conf, so we can set in-memory in it.

echo "select * from pyspark_db.pyspark_table;" | /work/openmldb/sbin/openmldb-cli.sh --spark_conf $(pwd)/test/sparksql.ini 
joblog shows it can't read hive table.

tm1


## Iceberg Test

Creation ref https://iceberg.apache.org/spark-quickstart/. We can set `enable.hive.support=false` in taskmanager to disable hive support, and set `spark.sql.catalogImplementation=in-memory` to use in-memory catalog. spark-shell/scala is ok, spark-sql may get databases in spark_catalog, but can't select them.

### Hive Catalog

you can cleanup the hive data by 
`docker-compose2 down hive-postgres hive-metastore && docker volume rm openmldb-compose_hive_postgres && docker-compose2 up -d`
cleanup: `docker exec deploy-node hadoop fs -rm -r "/user/hive/warehouse/*" "/user/hive/external_warehouse/*" "/user/hive/iceberg_storage/*"` 

- Step 1: create database and iceberg table in hive
```
docker exec deploy-node hadoop fs -mkdir -p /user/hive/external_warehouse # store iceberg metadata
docker exec deploy-node hadoop fs -mkdir -p /user/hive/iceberg_storage # store iceberg data
```
iceberg hive catalog must set `spark.sql.catalog.hive_prod.warehouse=../user/hive/iceberg_storage` to create table. Or must use hive to create table.

spark jar is hive-metastore-2.3.9.jar, compatible with hive 4.0.0-beta-1 metastore service.

https://iceberg.apache.org/docs/latest/getting-started/#creating-a-table

```
bash test/spark-with-iceberg-hive.sh
use hive_prod;
create database nyc;
use nyc;
select current_catalog(), current_database();
show tables;
CREATE TABLE taxis
(
  vendor_id bigint,
  trip_id bigint,
  trip_distance float,
  fare_amount double,
  store_and_fwd_flag string
)
PARTITIONED BY (vendor_id);
desc formatted taxis;

INSERT INTO taxis
VALUES (1, 1000371, 1.8, 15.32, 'N'), (2, 1000372, 2.5, 22.15, 'N'), (2, 1000373, 0.9, 9.01, 'N'), (1, 1000374, 8.4, 42.13, 'Y');
SELECT * FROM taxis;

desc formatted hive_prod.nyc.taxis;
select * from hive_prod.nyc.taxis;

-- no need to create taxis_out, openmldb select out can create table
```

```
spark-sql> desc formatted hive_prod.nyc.taxis;
vendor_id               bigint
trip_id                 bigint
trip_distance           float
fare_amount             double
store_and_fwd_flag      string

# Partitioning
Part 0                  vendor_id

# Metadata Columns
_spec_id                int
_partition              struct<vendor_id:bigint>
_file                   string
_pos                    bigint
_deleted                boolean

# Detailed Table Information
Name                    hive_prod.nyc.taxis
Location                hdfs://namenode:19000/user/hive/iceberg_storage/nyc.db/taxis
Provider                iceberg
Owner                   root
Table Properties        [current-snapshot-id=3471065469702081851,format=iceberg/parquet,format-version=2,write.parquet.compression-codec=zstd]
Time taken: 0.289 seconds, Fetched 22 row(s)
```

Location should be `Location                hdfs://namenode:19000/user/hive/iceberg_storage/nyc.db/taxis`.

P.S. An external table's location should not be located within managed warehouse root directory of its database, iceberg table should be external table and store in 
`metastore.warehouse.external.dir`, don't use the same path with `metastore.warehouse.dir`(default is `/user/hive/warehouse`) as iceberg table location.

- Step 2: test 

test openmldb <-> iceberg(hive catalog): test/iceberg-hive.sql

/work/openmldb/sbin/openmldb-cli.sh --spark_conf $(pwd)/test/spark.extra.ini < test/iceberg-hive.sql

- Step 3: validate

OpenMLDB can read/write iceberg table, we can check the table location and read them by spark.
```
DESC FORMATTED hive_prod.nyc.taxis;
SELECT * FROM hive_prod.nyc.taxis;
DESC FORMATTED hive_prod.nyc.taxis_out;
SELECT * FROM hive_prod.nyc.taxis_out;
```

You can see taxis_out has data.

And hive can read them too, EXTERNAL_TABLE with table_type ICEBERG. But before read, spark should `ALTER TABLE hive_prod.nyc.taxis SET TBLPROPERTIES ('engine.hive.enabled'='true');`, ref https://github.com/apache/iceberg/issues/1883.

```
Table Properties        [current-snapshot-id=3863655233664715445,engine.hive.enabled=true,format=iceberg/parquet,format-version=2,write.parquet.compression-codec=zstd]
```

### Hadoop Catalog

test/spark.extra.ini use hadoop part.

- Step 1: create iceberg table by spark
```
docker exec deploy-node hadoop fs -mkdir -p /user/hadoop_iceberg/
docker exec deploy-node hadoop fs -rm -r "/user/hadoop_iceberg/*"
bash test/spark-with-iceberg-hadoop.sh

SHOW NAMESPACES FROM hadoop_prod; -- can know prod namespace

USE hadoop_prod;
SELECT current_catalog();
CREATE TABLE hadoop_prod.nyc.taxis2 (
  vendor_id bigint,
  trip_id bigint,
  trip_distance float,
  fare_amount double,
  store_and_fwd_flag string); -- no need of USING iceberg?;
DESC FORMATTED hadoop_prod.nyc.taxis2;
INSERT INTO hadoop_prod.nyc.taxis2
VALUES (1, 1000371, 1.8, 15.32, 'N'), (2, 1000372, 2.5, 22.15, 'N'), (2, 1000373, 0.9, 9.01, 'N'), (1, 1000374, 8.4, 42.13, 'Y');
SELECT * FROM hadoop_prod.nyc.taxis2;
-- no need to create taxis_out2, openmldb select out can create table
```

- Step 2: test
```
/work/openmldb/sbin/openmldb-cli.sh --spark_conf $(pwd)/test/spark.extra.ini < test/iceberg-hadoop.sql
```

- Step 3: validate
You can check it on hdfs: docker exec deploy-node hadoop fs -ls /user/hadoop_iceberg/nyc/taxis

### Rest Catalog

Rest catalog service use unofficial docker image iceberg-rest, see
https://github.com/tabular-io/iceberg-rest-image and hive support https://github.com/tabular-io/iceberg-rest-image/pull/43.

And I use the hive catalog in previous chapter, so we can access table `<catalog>.nyc.taxis`. Cvt to rest catalog. Use test/spark.extra.ini rest part.
```
/work/openmldb/sbin/openmldb-cli.sh --spark_conf $(pwd)/test/spark.extra.ini < test/iceberg-rest.sql
```

### Session Catalog TODO

Spark 3.2.1 use hive metastore >=2.3.9 by default. Generally speaking, we can read hive >= 2.3.9. So hive-4.0.0-beta-1 metastore service can be used.

spark > 2.3 can read/write acid hive table? https://issues.apache.org/jira/browse/SPARK-15348

The bug we met when spark read hive acid(select * from acid_table):

```
MetaException(message:Your client does not appear to support insert-only tables. To skip capability checks, please set metastore.client.capability.check to false. This setting can be set globally, or on the client for the current metastore session. Note that this may lead to incorrect results, data loss, undefined behavior, etc. if your client is actually incompatible. You can also specify custom client capabilities via get_table_req API.)   Description  The server encountered an unexpected condition that prevented it from fulfilling the request.   Exception   javax.servlet.ServletException: javax.servlet.ServletException: MetaException(message:Your client does not appear to support insert-only tables. To skip capability checks, please set metastore.client.capability.check to false. This setting can be set globally, or on the client for the current metastore session. Note that this may lead to incorrect results, data loss, undefined behavior, etc. if your client is actually incompatible. You can also specify custom client capabilities via get_table_req API.) (libchurl.c:935)  (seg36 slice1 172.16.10.26:4000 pid=93248) (libchurl.c:935)
```

SET hive.txn.manager=org.apache.hadoop.hive.ql.lockmgr.DbTxnManager;
SET hive.support.concurrency=true;


insert-only table can be stored in parquet, but spark can't read it?
CREATE TABLE hive_insert_only_parquet(a int, b int) 
  STORED AS PARQUET
  TBLPROPERTIES ('transactional'='true',
  'transactional_properties'='insert_only');

spark-sql> desc formatted hive_insert_only_parquet;
a                       int
b                       int

# Detailed Table Information
Database                test_db
Table                   t2
Owner                   root
Created Time            Mon Jan 29 13:50:06 UTC 2024
Last Access             UNKNOWN
Created By              Spark 3.2.1
Type                    MANAGED
Provider                hive
Table Properties        [bucketing_version=2, transactional=true, transactional_properties=insert_only, transient_lastDdlTime=1706536206]
Location                hdfs://namenode:19000/user/hive/warehouse/test_db.db/t2
Serde Library           org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe
InputFormat             org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat
OutputFormat            org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat
Storage Properties      [serialization.format=1]
Partition Provider      Catalog
Time taken: 0.169 seconds, Fetched 19 row(s)

insert into hive_insert_only_parquet values (1,2);
select * from hive_insert_only_parquet;

spark insert, hive can't read; hive insert, spark can't read. Empty.
spark can get stats, but can't read.
Statistics              411 bytes, 1 rows

spark 3.2.1 + hive 3.1.2, acid works? iceberg hive catalog works? session catalog works?
Hive 3 not support java 11

create databse db312;
use db312;
CREATE TABLE acid_table (
  col1 INT,
  col2 STRING
)
STORED AS ORC
TBLPROPERTIES ('transactional'='true');
DESCRIBE FORMATTED db312.acid_table;
orc? parquet or csv works? only orc supports acid? MetaException(message:The table must be stored using an ACID compliant format (such as ORC): db312.acid_parquet) (state=08S01,code=1)

test orc acid
spark write, hive can't read   Error: Error while compiling statement: FAILED: NullPointerException null (state=42000,code=40000)

in hive-metastore container:
hive use local mapred, so needs set ENV JVM_ARGS="-Xms10240m -Xmx10240m" to avoid OOM.
beeline -u jdbc:hive2://hive-metastore:10000

create database test_db;
SET hive.txn.manager=org.apache.hadoop.hive.ql.lockmgr.DbTxnManager;
SET hive.support.concurrency=true;
create table test_db.crud_table (id INT, value STRING) STORED AS ORC TBLPROPERTIES ('transactional' = 'true');
insert into test_db.crud_table(id, value) values (1,'A'), (2,'B'), (3,'C');
select * from test_db.crud_table;

SUCCESS

insert only:

CREATE TABLE test_db.insert_only (
  col1 INT,
  col2 STRING
)
STORED AS ORC
TBLPROPERTIES (
  'transactional'='true',
  'transactional_properties'='insert_only'
);
desc formatted test_db.insert_only;
insert into test_db.insert_only(col1, col2) values (1,'A'), (2,'B'), (3,'C');
select * from test_db.insert_only;

openmldb create table like hive use df=`select * from <hive_table>`, then use df to create openmldb table. So we just need to test select *.

spark read test_db.crud_table or insert_only table, empty
even desc table:
```
transactional=true, transactional_properties=insert_only
Statistics              288 bytes, 3 rows
```

check about spark with hive3.1.2 dependency:

openmldb/spark/bin/spark-sql -c spark.openmldb.sparksql=true -c spark.sql.hive.metastore.version=3.1.2 -c spark.sql.hive.metastore.jars=maven

empty too

openmldb/spark/bin/spark-sql -c spark.openmldb.sparksql=true -c spark.sql.hive.metastore.version=3.1.2 -c spark.sql.hive.metastore.jars=maven -c spark.sql.warehouse.dir=hdfs://namenode:19000/user/hive/warehouse

failed too


spark 3.2.1 + hive 4.0.0-beta-1, acid(managed table) works?

hive-metastore container run beeline -u jdbc:hive2://

create database db;
use db;
SET hive.txn.manager=org.apache.hadoop.hive.ql.lockmgr.DbTxnManager;
SET hive.support.concurrency=true;
CREATE TABLE hive_insert_only_parquet(a int, b int) 
  STORED AS PARQUET
  TBLPROPERTIES ('transactional'='true',
  'transactional_properties'='insert_only');
insert into hive_insert_only_parquet values (1,2);
select * from hive_insert_only_parquet;
desc formatted db.hive_insert_only_parquet;

spark-3.5.0 bin/spark-sql -c spark.hadoop.hive.metastore.uris=thrift://hive-metastore:9083 other configs in spark/conf/hive-site.xml and core-site.xml
select * from db.hive_insert_only_parquet;
error: MetaException(message:Your client does not appear to support insert-only tables. To skip capability checks, please set metastore.client.capability.check to false. This setting can be set globally, or on the client for the current metastore session. Note that this may lead to incorrect results, data loss, undefined behavior, etc. if your client is actually incompatible. You can also specify custom client capabilities via get_table_req API.)

spark/jars:
-rw-r--r-- 1 huangwei staff  559K Jan 29 22:28 spark-hive-thriftserver_2.12-3.5.0.jar
-rw-r--r-- 1 huangwei staff  708K Jan 29 22:28 spark-hive_2.12-3.5.0.jar
-rw-r--r-- 1 huangwei staff  7.9M Jan 29 22:28 hive-metastore-2.3.9.jar
so still 2.3.9.

spark 3.5.0 can set to 3.1.3, spark 3.2.1 set to 3.1.2 https://spark.apache.org/docs/3.5.0/sql-data-sources-hive-tables.html#interacting-with-different-versions-of-hive-metastore

bin/spark-sql -c spark.openmldb.sparksql=true -c spark.sql.hive.metastore.version=3.1.3 -c spark.sql.hive.metastore.jars=maven -c spark.sql.warehouse.dir=hdfs://namenode:19000/user/hive/warehouse -c spark.hadoop.hive.metastore.uris=thrift://hive-metastore:9083

spark_hive.py can show tables, but select * from hive_insert_only_parquet failed. set spark.hive.metastore.client.capability.check no effect.

So iceberg session catalog can do that?




use hiveserver2 for spark test?

Make spark_catalog be hive catalog, like uris way:
```
spark.sql.catalog.spark_catalog = org.apache.iceberg.spark.SparkSessionCatalog
spark.sql.catalog.spark_catalog.type = hive
spark.sql.catalog.spark_catalog.uri = thrift://hive-metastore:9083
```
Notice that the catalog setted is spark_catalog, it's spark default catalog, so we can use spark_catalog.nyc.taxis or nyc.taxis. We can read/write tables.

```
spark-sql> desc formatted nyc.taxis;
vendor_id               bigint
trip_id                 bigint
trip_distance           float
fare_amount             double
store_and_fwd_flag      string

# Partitioning
Part 0                  vendor_id

# Metadata Columns
_spec_id                int
_partition              struct<vendor_id:bigint>
_file                   string
_pos                    bigint
_deleted                boolean

# Detailed Table Information
Name                    spark_catalog.nyc.taxis
Location                hdfs://namenode:19000/user/hive/iceberg_storage/nyc.db/taxis
Provider                iceberg
Owner                   root
Table Properties        [current-snapshot-id=3471065469702081851,format=iceberg/parquet,format-version=2,write.parquet.compression-codec=zstd]
Time taken: 0.289 seconds, Fetched 22 row(s)
```

If set hive_prod catalog to org.apache.iceberg.spark.SparkSessionCatalog, we can get tables in spark_catalog, but `select * from nyc.taxis;` get error:
```
java.lang.RuntimeException: java.lang.InstantiationException
        at org.apache.hadoop.util.ReflectionUtils.newInstance(ReflectionUtils.java:137)
        at org.apache.spark.rdd.HadoopRDD.getInputFormat(HadoopRDD.scala:191)
```


TODO hive ACID(managed?)
```
cd $HIVE_HOME
bin/beeline -u jdbc:hive2://hive-metastore:10000  
-- Connected to: Apache Hive (version 4.0.0-beta-1)
-- Driver: Hive JDBC (version 4.0.0-beta-1)
-- NOTE: don't make driver be 2.3.9, it's not compatible with hive 4.0.0-beta-1 metastore service? get some warning

SET hive.support.concurrency=true;
SET hive.txn.manager=org.apache.hadoop.hive.ql.lockmgr.DbTxnManager;
# The follwoing are not required if you are using Hive 2.0
SET hive.enforce.bucketing=true;
SET hive.exec.dynamic.partition.mode=nonstrict;
# The following parameters are required for standalone hive metastore
SET hive.compactor.initiator.on=true;
SET hive.compactor.worker.threads=1

create databse db312;
use db312;
CREATE TABLE acid_table (
  col1 INT,
  col2 STRING
)
STORED AS ORC
TBLPROPERTIES ('transactional'='true');
DESCRIBE FORMATTED db312.acid_table;
-- transactional is true


-- compare with iceberg table
DESC FORMATTED nyc.taxis;

```


spark.hadoop.hive.metastore.uris=thrift://hive-metastore:9083 can't work? log shows it can't link to metastore service.
```
24/01/26 05:55:43 INFO DataSourceUtil$: load data from catalog table, format hive, paths: hive://acid_table List()
24/01/26 05:55:43 DEBUG DataSourceUtil$: session catalog org.apache.spark.sql.hive.HiveSessionCatalog@49bb808f
24/01/26 05:55:43 DEBUG SparkSqlParser: Parsing command: show tables
24/01/26 05:55:43 DEBUG CatalystSqlParser: Parsing command: spark_grouping_id
24/01/26 05:55:44 INFO HiveConf: Found configuration file null
```
It can't work in openmldb. It needs other options in hive-site.xml, and I don't know which options are needed, just copy the hive-site.xml to spark home.
And spark-sql load hive-site.xml automatically, probably it loads by $HIVE_HOME.

In spark-sql(just read hive-site.xml), it's ok:
```
openmldb/spark/bin/spark-sql -c spark.openmldb.sparksql=true
show databases;
use default;
desc formatted default.acid_table;
INSERT INTO acid_table VALUES (1, 'a'), (2, 'b'), (3, 'c');
SELECT * FROM acid_table;
```
In OpenMLDB, needs to copy hive-site.xml to tm1 host:
```
cp /opt/hive/conf/hive-site.xml openmldb/spark/conf/
deploya
/work/openmldb/sbin/openmldb-cli.sh < test/create_like_hive_acid.sql
```

Can I use iceberg session catalog?
run spark-sql on tm1, to avoid HIVE_HOME effect. If we use hive_prod configs, in hive_prod catalog default db, **we can't see acid_table(it's not iceberg table)**.

use session catalog:
```
export JAVA_HOME=/usr/local/openjdk-11/
/work/openmldb/spark/bin/spark-sql -c spark.openmldb.sparksql=true -c spark.sql.catalog.spark_catalog=org.apache.iceberg.spark.SparkSessionCatalog \
-c spark.sql.catalog.spark_catalog.type=hive \
-c spark.sql.catalog.spark_catalog.uri=thrift://hive-metastore:9083
```
can't see any table in default db, in spark_catalog catalog.
So hive-site.xml is needed. 

In deploy-node
spark-sql can use hive-site.xml to read/write acid table. But if no org.apache.iceberg.spark.SparkSessionCatalog, we can't select iceberg table in hive. If add the config about org.apache.iceberg.spark.SparkSessionCatalog, we can read/write iceberg table.


To avoid uris effect, run in deploy-node:
enable.hive.support=false -> spark.sql.catalogImplementation=hive or others
cp /opt/hive/conf/hive-site.xml openmldb/spark/conf/
deploya
stopt # disable hive support needs restart tm
starta

TODO test in openmldb?

### spark without hive support
deploy-node: ospark 3.2.1, hive config in hive 4.0.0-beta-1 client(/opt/hive)
tm1: spark 3.2.1

only ospark, config `spark.sql.catalogImplementation` defines catalog, we set it to `spark.sql.catalogImplementation=in-memory`, so we won't use hivesessioncatalog.
tm1:
export JAVA_HOME=/usr/local/openjdk-11/
/work/openmldb/spark/bin/spark-sql -c spark.openmldb.sparksql=true -c spark.sql.catalogImplementation=in-memory

/work/openmldb/spark/bin/spark-shell -c spark.openmldb.sparksql=true -c spark.sql.catalogImplementation=in-memory
```
scala> spark.sessionState.catalog
res0: org.apache.spark.sql.catalyst.catalog.SessionCatalog = org.apache.spark.sql.catalyst.catalog.SessionCatalog@bdc5584
```
So we uses the normal session catalog, not hive catalog.

If no catalogImpl setting:
```
/work/openmldb/spark/bin/spark-shell -c spark.openmldb.sparksql=true
scala> spark.sessionState.catalog
res0: org.apache.spark.sql.catalyst.catalog.SessionCatalog = org.apache.spark.sql.hive.HiveSessionCatalog@24d25c43
```
ospark spark session will have openmldb session, so it may use openmldb.zk.xxx when create openmldb session, but where is hive setting?

`enable.hive.support` is config of taskmanager, won't effect on spark home.

set spark-shell/spark-sql log level to info
You can see `Created Spark session with Hive support`, so `hiveClassesArePresent` will effect too. If we have hive classes, we will use hive catalog if no `spark.sql.catalogImplementation`.

If we set `spark.sql.catalogImplementation=in-memory`, it works on spark home. 
But if we use taskmanager to run, we should disable hive support too.(To avoid set spark.sql.catalogImplementation=hive when job submit)

in spark-shell, if in-memory, spark_catalog won't have nyc database and table in it. `show tables in hive_prod` can get them.
But in spark-sql, even in in-memory, `show databases` can see nyc, in spark_catalog. But can't select them.
```
spark-sql> use spark_catalog;
24/01/30 11:13:21 INFO OpenmldbSession: Try to execute OpenMLDB SQL: use spark_catalog
24/01/30 11:13:21 INFO HiveMetaStore: 0: get_database: default
spark-sql> select * from nyc.taxis_out_auto_create;
24/01/30 11:15:43 INFO OpenmldbSession: Try to execute OpenMLDB SQL: select * from nyc.taxis_out_auto_create
24/01/30 11:15:43 INFO HiveMetaStore: 0: get_database: nyc
24/01/30 11:15:43 INFO audit: ugi=root  ip=unknown-ip-addr      cmd=get_database: nyc
...
java.lang.RuntimeException: java.lang.InstantiationException
        at org.apache.hadoop.util.ReflectionUtils.newInstance(ReflectionUtils.java:137)
        at org.apache.spark.rdd.HadoopRDD.getInputFormat(HadoopRDD.scala:191)
        at org.apache.spark.rdd.HadoopRDD.getPartitions(HadoopRDD.scala:205)
        at org.apache.spark.rdd.RDD.$anonfun$partitions$2(RDD.scala:300)
        at scala.Option.getOrElse(Option.scala:189)
        at org.apache.spark.rdd.RDD.partitions(RDD.scala:296)
        at org.apache.spark.rdd.MapPartitionsRDD.getPartitions(MapPartitionsRDD.scala:49)
        at org.apache.spark.rdd.RDD.$anonfun$partitions$2(RDD.scala:300)
        at scala.Option.getOrElse(Option.scala:189)
        at org.apache.spark.rdd.RDD.partitions(RDD.scala:296)
        at org.apache.spark.rdd.MapPartitionsRDD.getPartitions(MapPartitionsRDD.scala:49)
        at org.apache.spark.rdd.RDD.$anonfun$partitions$2(RDD.scala:300)
```
Still use hive metastore service, and only metadata, why? don't use spark-sql, **use spark-shell is better**.

So we can create a session without hive support and add iceberg session catalog?

/work/openmldb/spark/bin/spark-sql -c spark.openmldb.sparksql=true -c spark.sql.catalog.spark_catalog=org.apache.iceberg.spark.SparkSessionCatalog \
-c spark.sql.catalog.spark_catalog.type=hive \
-c spark.sql.catalog.spark_catalog.uri=thrift://hive-metastore:9083 \
-c spark.sql.catalogImplementation=in-memory
Caused by: java.net.ConnectException: Connection refused (Connection refused)
        at java.base/java.net.PlainSocketImpl.socketConnect(Native Method)
        at java.base/java.net.AbstractPlainSocketImpl.doConnect(Unknown Source)
        at java.base/java.net.AbstractPlainSocketImpl.connectToAddress(Unknown Source)
        at java.base/java.net.AbstractPlainSocketImpl.connect(Unknown Source)
        at java.base/java.net.SocksSocketImpl.connect(Unknown Source)
        at java.base/java.net.Socket.connect(Unknown Source)
        at org.apache.thrift.transport.TSocket.open(TSocket.java:221)
        ... 46 more
)
        at org.apache.hadoop.hive.metastore.HiveMetaStoreClient.open(HiveMetaStoreClient.java:527)
        at org.apache.hadoop.hive.metastore.HiveMetaStoreClient.<init>(HiveMetaStoreClient.java:245)
        at org.apache.hadoop.hive.ql.metadata.SessionHiveMetaStoreClient.<init>(SessionHiveMetaStoreClient.java:70)
        ... 43 more

Exception in thread "main" java.lang.IllegalArgumentException: Inconsistent Hive metastore URIs: thrift://localhost:9083 (Spark session) != thrift://hive-metastore:9083 (spark_catalog)
        at org.apache.iceberg.relocated.com.google.common.base.Preconditions.checkArgument(Preconditions.java:445)
        at org.apache.iceberg.spark.SparkSessionCatalog.validateHmsUri(SparkSessionCatalog.java:336)
        at org.apache.iceberg.spark.SparkSessionCatalog.initialize(SparkSessionCatalog.java:311)
        at org.apache.spark.sql.connector.catalog.Catalogs$.load(Catalogs.scala:65)
        at org.apache.spark.sql.connector.catalog.CatalogManager.loadV2SessionCatalog(CatalogManager.scala:67)
        at org.apache.spark.sql.connector.catalog.CatalogManager.$anonfun$v2SessionCatalog$2(CatalogManager.scala:86)
        at scala.collection.mutable.HashMap.getOrElseUpdate(HashMap.scala:86)
        at org.apache.spark.sql.connector.catalog.CatalogManager.$anonfun$v2SessionCatalog$1(CatalogManager.scala:86)
        at scala.Option.map(Option.scala:230)
        at org.apache.spark.sql.connector.catalog.CatalogManager.v2SessionCatalog(CatalogManager.scala:85)
        at org.apache.spark.sql.connector.catalog.CatalogManager.catalog(CatalogManager.scala:51)
        at org.apache.spark.sql.connector.catalog.CatalogManager.currentCatalog(CatalogManager.scala:122)
        at org.apache.spark.sql.connector.catalog.CatalogManager.currentNamespace(CatalogManager.scala:93)
        at org.apache.spark.sql.internal.CatalogImpl.currentDatabase(CatalogImpl.scala:67)
        at org.apache.spark.sql.hive.thriftserver.SparkSQLCLIDriver$.currentDB$1(SparkSQLCLIDriver.scala:288)
        at org.apache.spark.sql.hive.thriftserver.SparkSQLCLIDriver$.promptWithCurrentDB$1(SparkSQLCLIDriver.scala:295)
        at org.apache.spark.sql.hive.thriftserver.SparkSQLCLIDriver$.main(SparkSQLCLIDriver.scala:299)
        at org.apache.spark.sql.hive.thriftserver.SparkSQLCLIDriver.main(SparkSQLCLIDriver.scala)
        at java.base/jdk.internal.reflect.NativeMethodAccessorImpl.invoke0(Native Method)
        at java.base/jdk.internal.reflect.NativeMethodAccessorImpl.invoke(Unknown Source)
        at java.base/jdk.internal.reflect.DelegatingMethodAccessorImpl.invoke(Unknown Source)
        at java.base/java.lang.reflect.Method.invoke(Unknown Source)
        at org.apache.spark.deploy.JavaMainApplication.start(SparkApplication.scala:52)

iceberg will read `hive.metastore.uris`, must have -c spark.hadoop.hive.metastore.uris=thrift://hive-metastore:9083 , otherwise use localhost:9083.

/work/openmldb/spark/bin/spark-shell -c spark.openmldb.sparksql=true -c spark.sql.catalog.spark_catalog=org.apache.iceberg.spark.SparkSessionCatalog \
-c spark.sql.catalog.spark_catalog.type=hive \
-c spark.sql.catalog.spark_catalog.uri=thrift://hive-metastore:9083 \
-c spark.hadoop.hive.metastore.uris=thrift://hive-metastore:9083

```
scala> spark.sessionState.catalog
res0: org.apache.spark.sql.catalyst.catalog.SessionCatalog = org.apache.spark.sql.catalyst.catalog.SessionCatalog@70915da3
scala> sql("select current_catalog();").show()
SLF4J: Failed to load class "org.slf4j.impl.StaticMDCBinder".
SLF4J: Defaulting to no-operation MDCAdapter implementation.
SLF4J: See http://www.slf4j.org/codes.html#no_static_mdc_binder for further details.
+-----------------+
|current_catalog()|
+-----------------+
|    spark_catalog|
+-----------------+
```

hive create tables:
```
beeline -u jdbc:hive2://
SET hive.support.concurrency=true;
SET hive.txn.manager=org.apache.hadoop.hive.ql.lockmgr.DbTxnManager;
create table crud_table (id INT, value STRING) STORED AS ORC TBLPROPERTIES ('transactional' = 'true');
insert into crud_table(id, value) values (1,'A'), (2,'B'), (3,'C');
create table insert_only (id INT, value STRING) STORED AS PARQUET TBLPROPERTIES ('transactional' = 'true', 'transactional_properties'='insert_only');
insert into insert_only(id, value) values (1,'A'), (2,'B'), (3,'C');
create table normal_table (id INT, value STRING) STORED AS PARQUET;
insert into normal_table(id, value) values (1,'A'), (2,'B'), (3,'C');

SET iceberg.catalog.another_hive.type=hive;
SET iceberg.catalog.another_hive.uri=thrift://hive-metastore:9083;
SET iceberg.catalog.another_hive.clients=10;
SET iceberg.catalog.another_hive.warehouse=hdfs://namenode:19000/user/hive/warehouse;
create table iceberg_table (id INT, value STRING) STORED BY ICEBERG TBLPROPERTIES ('iceberg.catalog'='another_hive');
insert into iceberg_table(id, value) values (1,'A'), (2,'B'), (3,'C');
desc formatted iceberg_table;
create external table external_table (id INT, value STRING) STORED BY ICEBERG;
insert into external_table(id, value) values (1,'A'), (2,'B'), (3,'C');

select * from crud_table;

create database db;


```

spark-shell read:
```
/work/openmldb/spark/bin/spark-shell -c spark.openmldb.sparksql=true -c spark.sql.catalog.spark_catalog=org.apache.iceberg.spark.SparkSessionCatalog -c spark.sql.catalog.spark_catalog.type=hive -c spark.sql.catalog.spark_catalog.uri=thrift://hive-metastore:9083 -c spark.hadoop.hive.metastore.uris=thrift://hive-metastore:9083
scala> sql("show tables").show()
+---------+--------------+-----------+
|namespace|     tableName|isTemporary|
+---------+--------------+-----------+
|  default|  normal_table|      false|
|  default|    crud_table|      false|
|  default|   insert_only|      false|
|  default| iceberg_table|      false|
|  default|external_table|      false|
+---------+--------------+-----------+
```

can read normal_table(EXTERNAL_TABLE), but transactional tables(MANAGED_TABLE) all empty, hive can read them.

hive can't insert and select iceberg table? insert actually works, hadoop fs can get files, but select empty.
desc formatted iceberg_table; in hive shows row 0.???

hive create table stored by iceberg should set more configs?


24/01/30 07:07:58 INFO SharedState: Setting hive.metastore.warehouse.dir ('null') to the value of spark.sql.warehouse.dir.
24/01/30 07:07:58 INFO SharedState: Warehouse path is 'hdfs://namenode:19000/user/hive/warehouse'.
24/01/30 07:08:00 INFO ConfigReflections$: Native Spark Configuration: spark.sql.session.timeZone -> Etc/UTC
24/01/30 07:08:00 INFO ConfigReflections$: Native Spark Configuration: openmldb.sparksql -> true
24/01/30 07:08:00 INFO OpenmldbSession: Print OpenMLDB version
24/01/30 07:08:00 INFO OpenmldbSession: Spark: 3.2.1, OpenMLDB: 0.8.4-SNAPSHOT-2fd40ff
24/01/30 07:08:00 WARN OpenmldbSession: openmldb.zk.cluster or openmldb.zk.root.path is not set and do not register OpenMLDB tables
24/01/30 07:08:00 INFO HiveUtils: Initializing HiveMetastoreConnection version 2.3.9 using Spark classes.
24/01/30 07:08:00 INFO HiveClientImpl: Warehouse location for Hive client (version 2.3.9) is hdfs://namenode:19000/user/hive/warehouse
24/01/30 07:08:00 WARN HiveConf: HiveConf of name hive.stats.jdbc.timeout does not exist
24/01/30 07:08:00 WARN HiveConf: HiveConf of name hive.stats.retries.wait does not exist
24/01/30 07:08:00 INFO HiveMetaStore: 0: Opening raw store with implementation class:org.apache.hadoop.hive.metastore.ObjectStore
24/01/30 07:08:00 INFO ObjectStore: ObjectStore, initialize called
24/01/30 07:08:00 INFO Persistence: Property hive.metastore.integral.jdo.pushdown unknown - will be ignored
24/01/30 07:08:00 INFO Persistence: Property datanucleus.cache.level2 unknown - will be ignored
24/01/30 07:08:01 INFO ObjectStore: Setting MetaStore object pin classes with hive.metastore.cache.pinobjtypes="Table,StorageDescriptor,SerDeInfo,Partition,Database,Type,FieldSchema,Order"
24/01/30 07:08:01 INFO MetaStoreDirectSql: Using direct SQL, underlying DB is POSTGRES
24/01/30 07:08:01 INFO ObjectStore: Initialized ObjectStore
24/01/30 07:08:01 INFO HiveMetaStore: Added admin role in metastore
24/01/30 07:08:01 INFO HiveMetaStore: Added public role in metastore
24/01/30 07:08:01 INFO HiveMetaStore: No user is added in admin role, since config is empty
24/01/30 07:08:02 INFO HiveMetaStore: 0: get_database: default


SparkSessionCatalog is not a standalone catalog? https://iceberg.apache.org/docs/latest/getting-started/#adding-catalogs
## Thanks

https://github.com/adiii717/docker-container-ssh

https://github.com/big-data-europe/docker-hadoop/

https://github.com/tabular-io/iceberg-rest-image 
