# OpenMLDB Cluster

OpenMLDB with all components and hdfs service.

```bash
docker-compose build <service> # build image if you modify Dockerfile

docker-compose2 --env-file compose.env -f hadoop-compose.yml -f hive-compose.yml -f compose.yml down -v --remove-orphans
docker-compose2 --env-file compose.env -f hadoop-compose.yml -f hive-compose.yml -f compose.yml up -d
```

cleanup storage:

```bash
docker volume ls | grep openmldb-compose | awk '{print$2}' | xargs docker volume rm
```

## compose

You can do anything in deploy-node. In deploy-node, run hadoop or beeline, no need for conf in `$HADOOP_HOME` or `$HIVE_HOME`.

`docker-compose2 --env-file compose.env -f hadoop-compose.yml -f hive-compose.yml -f compose.yml ps`

### Hadoop

In `hadoop-compose.yml`, use image `bde2020/hadoop...`, can't update hadoop easily. But we don't need to change it frequently. Hive 4.0.0 can use hadoop 3.3.6.

Hadoop is simple, so you can access it just by url, like `hdfs://namenode:9000/`. So spark can access it without any hadoop config.

You can use `hadoop fs -fs hdfs://namenode:9000 ...` to debug on hdfs.

### Hive

If you use beeline, just need the url and the executable: `beeline -u jdbc:hive2://hiveserver2:10000/`. No extra conf is needed.

Spark-shell will try to use hive to be built-in catalog, if has hive dependencies, even no hive conf, see **the logic in `org.apache.spark.repl.Main.createSparkSession()`**. In spark-shell, you can see `INFO Main: Created Spark session with Hive support` by default.

And spark-sql can't disable hive catalog by config `spark.sql.catalogImplementation=in-memory`, it always loads hive as built-in catalog. Ridiculous! So we can't check iceberg config about session catalog. spark-sql always can read hive databases in spark_catalog.

pyspark and spark-submit will use in-memory catalog by default.** But we will add config `spark.sql.catalogImplementation=hive` for OpenMLDB offline job, if we have `enable.hive.support`(default is true).

So use pyspark or taskmanager submit spark job. pyspark  is not recomended too? TODO

Offline job way:

- sql: only select
- submit batchjob can support full spark sql
  - `$SPARK_HOME/bin/spark-submit --master local --class com._4paradigm.openmldb.batchjob.RunBatchAndShow --properties-file /work/test/sparksql.ini /work/openmldb/taskmanager/lib/openmldb-batchjob-*.jar "<sql>"`

some tips:

```bash
$SPARK_HOME/bin/spark-submit --master local --class com._4paradigm.openmldb.batchjob.RunBatchAndShow --properties-file /work/test/sparksql.ini /work/openmldb/taskmanager/lib/openmldb-batchjob-*.jar "SHOW NAMESPACES FROM hive_prod;" # error if no hive_prod config
$SPARK_HOME/bin/spark-submit --master local --class com._4paradigm.openmldb.batchjob.RunBatchAndShow --properties-file /work/test/sparksql.ini /work/openmldb/taskmanager/lib/openmldb-batchjob-*.jar "SHOW NAMESPACES;" # no hive databases if just hive_prod, and no changes even add session catalog
```

Iceberg test lastest:

hive_prod, you can get db in hive, but **no tables**, `show tables from hive_prod.db` will fail on `Caused by: org.apache.thrift.TApplicationException: Internal error processing get_table_objects_by_name`, cuz in hive_prod.db, all hive table, no iceberg table. We can create one iceberg table by hive_prod.

`$SPARK_HOME/bin/spark-sql --properties-file /work/test/sparksql.ini`, don't try to test on spark_catalog, just create table in hive_prod.

```sql
use hive_prod;
create database nyc_ice_hive;
use nyc_ice_hive;
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

desc formatted hive_prod.nyc_ice_hive.taxis;
select * from hive_prod.nyc_ice_hive.taxis;
```

`show tables from hive_prod.nyc_ice_hive` can read iceberg table.

```sql
+------------+---------+-----------+
|   namespace|tableName|isTemporary|
+------------+---------+-----------+
|nyc_ice_hive|    taxis|      false|
+------------+---------+-----------+
```

So why we eeed to use SparkSessionCatalog?

We can't get any db in spark_catalog if in-memory. SparkSessionCatalog must be spark_catalog, can't choose other names.

If set `spark.sql.catalogImplementation=hive`, we can get all metadata in hive. But if select the iceberg table in hive built-in catalog, got error `Caused by: java.lang.InstantiationException`. So if we want to read iceberg table when we can read hive tables, add session catalog.
After set SparkSessionCatalog, we can select iceberg tables. 3.2.1 and 3.5.0 both work.

Spark v3.5.0:

```
cd /work/test
# curl -SLO https://dlcdn.apache.org/spark/spark-3.5.0/spark-3.5.0-bin-hadoop3.tgz
wget https://mirror.sjtu.edu.cn/apache/spark/spark-3.5.0/spark-3.5.0-bin-hadoop3.tgz
export SPARK_HOME=/work/test/spark-3.5.0-bin-hadoop3
```

sbt scala is more helpful.

sbt package

mvn package

Java and scala cvt troubles in java test app, better to use scala. But sbt network is disgusting too. Decide by yourself.

$SPARK_HOME/bin/spark-submit --class "SimpleApp" \
  --master local[4] \
  --properties-file /work/test/sparksql.ini \
  /work/test/java/target/simple-project-1.0.jar

$SPARK_HOME/bin/spark-submit --class "SimpleApp" \
  --master local[4] \
  --properties-file /work/test/sparksql.ini \
  /work/test/scala/target/scala-2.12/simple-project_2.12-1.0.jar



When `enable.hive.support=false` run `/work/openmldb/sbin/openmldb-cli.sh --spark_conf=$(pwd)/test/sparksql.ini < test/spark_test.sql`, in OpenMLDB offline job log, you can see:

```log
24/02/04 06:07:09 INFO SharedState: spark.sql.warehouse.dir is not set, but hive.metastore.warehouse.dir is set. Setting spark.sql.warehouse.dir to the value of hive.metastore.warehouse.dir.
24/02/04 06:07:10 INFO SharedState: Warehouse path is 'hdfs://namenode:9000/user/hive/warehouse'.
```

But no Hive related logs. When `enable.hive.support=true`, it'll be:

```log
24/02/04 06:18:19 INFO SharedState: spark.sql.warehouse.dir is not set, but hive.metastore.warehouse.dir is set. Setting spark.sql.warehouse.dir to the value of hive.metastore.warehouse.dir.
24/02/04 06:18:20 INFO SharedState: Warehouse path is 'hdfs://namenode:9000/user/hive/warehouse'.
...
24/02/04 06:18:28 INFO HiveConf: Found configuration file file:/work/openmldb/spark/conf/hive-site.xml
24/02/04 06:18:28 INFO HiveUtils: Initializing HiveMetastoreConnection version 2.3.9 using Spark classes.
24/02/04 06:18:29 INFO HiveClientImpl: Warehouse location for Hive client (version 2.3.9) is hdfs://namenode:9000/user/hive/warehouse
24/02/04 06:18:29 WARN HiveConf: HiveConf of name hive.stats.jdbc.timeout does not exist
24/02/04 06:18:29 WARN HiveConf: HiveConf of name hive.stats.retries.wait does not exist
24/02/04 06:18:29 INFO HiveMetaStore: 0: Opening raw store with implementation class:org.apache.hadoop.hive.metastore.ObjectStore
```

**We need more than a metastore uri to use spark read/write hive.** Spark needs postgresql configs and maybe more. For simplicity, I use hive-site.xml, copy `hive-site.xml` to spark conf dir, so that Spark on deploy-node and taskmanager containers(deploy spark will copy the conf) can read the conf.

And you should check keyword `HiveConf` in log to know if session use hive as built-in catalog.

## test

test hdfs:

```bash
echo 'sc.parallelize(List( (1,"a"), (2,"b") )).toDF("key","value").write.mode("overwrite").option("header", "true").csv("hdfs://namenode:9000/tmp/shell-out")' | $SPARK_HOME/bin/spark-shell
```

then you can read:

```bash
echo 'spark.read.option("header", "true").csv("hdfs://namenode:19000/tmp/shell-out").show()' | $SPARK_HOME/bin/spark-shell
```

Debug hdfs:
TODO

Debug zk:

```bash
echo stat | nc openmldb-compose-zk-1 2181
```

To run openmldb test, scripts are in dir test/, run:

```bash
/work/openmldb/sbin/openmldb-cli.sh < test/test.sql
```

You can check it on hdfs:
`echo 'spark.read.option("header", "true").csv("hdfs://namenode:19000/test/").show()' | $SPARK_HOME/bin/spark-shell
`

### Hive official

I've tried <https://github.com/apache/hive/blob/master/packaging/src/docker/docker-compose.yml> set warehouse to hdfs path(not local path), and use postgres.
But hive will use `- warehouse:/opt/hive/data/warehouse` to store table, so it's not compatible with hdfs. Set hadoop conf core-site.xml in hadoop home, and hiveserver2 use the same confs.

Create hive env only: `docker-compose2 --env-file compose.env -f hadoop-compose.yml -f hive-compose.yml up -d`

Debug postegre: `psql metastore_db -U hive`

Debug hive: `docker exec -it hiveserver2 beeline -u 'jdbc:hive2://hiveserver2:10000/'`

### Hive Self Build(backup)

I tried <https://github.com/big-data-europe/docker-hive>, but only hive3 in <https://github.com/big-data-europe/docker-hive/pull/56/files#> and no iceberg support, I want hive 4.0.0. So build hive docker image by myself. see [Dockerfile](hive/Dockerfile).

```bash
https://dlcdn.apache.org/hadoop/common/hadoop-3.3.6/hadoop-3.3.6.tar.gz
https://dlcdn.apache.org/hive/hive-4.0.0-beta-1/apache-hive-4.0.0-beta-1-bin.tar.gz
```

Mainland can use url `https://mirror.sjtu.edu.cn/apache/...`.

Hive uses Hadoop, so you must have Hadoop in your path(client side, connect to hdfs cluster), and then install hive.

```bash
export JAVA_HOME=/usr/lib/jvm/java-1.8.0-openjdk-1.8.0.242.b08-0.el7_7.x86_64/jre
export HADOOP_HOME=$(pwd)/hadoop-3.3.6
export HADOOP_CONF_DIR=$HADOOP_HOME/etc/hadoop
export HIVE_HOME=$(pwd)/apache-hive-4.0.0-beta-1-bin

cp core-site.xml $HADOOP_HOME/etc/hadoop
# /user/hive/warehouse (aka hive.metastore.warehouse.dir default value) 
$HADOOP_HOME/bin/hadoop fs -fs hdfs://localhost:19000 -mkdir       /tmp
$HADOOP_HOME/bin/hadoop fs -fs hdfs://localhost:19000 -mkdir -p      /user/hive/warehouse
$HADOOP_HOME/bin/hadoop fs -fs hdfs://localhost:19000 -chmod g+w   /tmp
$HADOOP_HOME/bin/hadoop fs -fs hdfs://localhost:19000 -chmod g+w   /user/hive/warehouse
```

Derby sucks, so use postgres for cluster. Postgres image is enough.

Hive by default gets its configuration from `<install-dir>/conf/hive-default.xml`, the location of the Hive configuration directory can be changed by setting the `HIVE_CONF_DIR` environment variable. Configuration variables can be changed by (re-)defining them in `<install-dir>/conf/hive-site.xml`.

So we just config `hive-site.xml`.

```bash
cp hive-site.xml $HIVE_HOME/conf
$HIVE_HOME/bin/schematool -dbType postgres -initSchema --verbose
$HIVE_HOME/bin/hive --service metastore &
# hiveserver2 just for test, don't make it as a service
$HIVE_HOME/bin/hiveserver2 & # server
$HIVE_HOME/bin/beeline -u jdbc:hive2:// # cli on server
$HIVE_HOME/bin/beeline -u jdbc:hive2://metastore:10000 # cli on client
# in beeline or hive cli
show databases; # one `default` db
```

#### OpenMLDB to hive

OpenMLDB Spark to hive needs hive conf, cuz it use metastore, not hiveserver2 jdbc. You can test by just run `spark-shell/spark-sql` with metastore uri arg.
OpenMLDB Spark doesn't have pyspark env, but I have installed pyspark in deploy-node. But pyspark 3.2.1 has some limitations, so I use spark-shell to test too.

```bash
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

Creation ref <https://iceberg.apache.org/spark-quickstart/>. We can set `enable.hive.support=false` in taskmanager to disable hive support, and set `spark.sql.catalogImplementation=in-memory` to use in-memory catalog. spark-shell/scala is ok, spark-sql may get databases in spark_catalog, but can't select them.

OpenMLDB Spark should add iceberg jars, if version < 0.8.5. <https://iceberg.apache.org/releases/>. And spark need <https://iceberg.apache.org/docs/latest/hive/> to use hive catalog. download iceberg-hive-runtime.

```bash
wget https://search.maven.org/remotecontent?filepath=org/apache/iceberg/iceberg-spark-runtime-3.2_2.12/1.4.3/iceberg-spark-runtime-3.2_2.12-1.4.3.jar
wget https://repo1.maven.org/maven2/org/apache/iceberg/iceberg-hive-runtime/1.4.3/iceberg-hive-runtime-1.4.3.jar
```

If download slowly, download them from <https://developer.aliyun.com/mvn/search>.

`cp iceberg-hive-runtime-1.4.2.jar $SPARK_HOME/jars` or add conf `spark.jars.packages=org.apache.iceberg:iceberg-spark-runtime-3.2_2.12:1.4.3;org.apache.iceberg:iceberg-hive-runtime:1.4.3`.

### Hive Catalog

you can cleanup the hive data by
`docker-compose2 down hive-postgres hive-metastore && docker volume rm openmldb-compose_hive_postgres && docker-compose2 up -d`
cleanup: `docker exec deploy-node hadoop fs -rm -r "/user/hive/warehouse/*" "/user/hive/external_warehouse/*" "/user/hive/iceberg_storage/*"`

- Step 1: create database and iceberg table in hive

```bash
docker exec deploy-node hadoop fs -mkdir -p /user/hive/external_warehouse # store iceberg metadata
docker exec deploy-node hadoop fs -mkdir -p /user/hive/iceberg_storage # store iceberg data
```

iceberg hive catalog must set `spark.sql.catalog.hive_prod.warehouse=../user/hive/iceberg_storage` to create table. Or must use hive to create table.

spark jar is hive-metastore-2.3.9.jar, compatible with hive 4.0.0-beta-1 metastore service.

<https://iceberg.apache.org/docs/latest/getting-started/#creating-a-table>

```bash
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

```sql
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

```sql
DESC FORMATTED hive_prod.nyc.taxis;
SELECT * FROM hive_prod.nyc.taxis;
DESC FORMATTED hive_prod.nyc.taxis_out;
SELECT * FROM hive_prod.nyc.taxis_out;
```

You can see taxis_out has data.

And hive can read them too, EXTERNAL_TABLE with table_type ICEBERG. But before read, spark should `ALTER TABLE hive_prod.nyc.taxis SET TBLPROPERTIES ('engine.hive.enabled'='true');`, ref <https://github.com/apache/iceberg/issues/1883>.

```sql
Table Properties        [current-snapshot-id=3863655233664715445,engine.hive.enabled=true,format=iceberg/parquet,format-version=2,write.parquet.compression-codec=zstd]
```

### Hadoop Catalog

test/spark.extra.ini use hadoop part.

- Step 1: create iceberg table by spark

```bash
hadoop fs -fs hdfs://namenode:9000 -mkdir -p /user/hadoop_iceberg/
hadoop fs -fs hdfs://namenode:9000 -rm -r "/user/hadoop_iceberg/*"
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

```bash
/work/openmldb/sbin/openmldb-cli.sh --spark_conf $(pwd)/test/spark.extra.ini < test/iceberg-hadoop.sql
```

- Step 3: validate
You can check it on hdfs: docker exec deploy-node hadoop fs -ls /user/hadoop_iceberg/nyc/taxis

### Rest Catalog

Rest catalog service use unofficial docker image iceberg-rest, see
<https://github.com/tabular-io/iceberg-rest-image> and hive support <https://github.com/tabular-io/iceberg-rest-image/pull/43>.

And I use the hive catalog in previous chapter, so we can access table `<catalog>.nyc.taxis`. Cvt to rest catalog. Use test/spark.extra.ini rest part.

```bash
/work/openmldb/sbin/openmldb-cli.sh --spark_conf $(pwd)/test/spark.extra.ini < test/iceberg-rest.sql
```

### Session Catalog TODO

Spark 3.2.1 use hive metastore >=2.3.9 by default. Generally speaking, we can read hive >= 2.3.9. So hive-4.0.0-beta-1 metastore service can be used.

spark > 2.3 can read/write acid hive table? <https://issues.apache.org/jira/browse/SPARK-15348>

use beeline to create hive tables, transactional tables are MANAGED_TABLE(and must be bucketed), normal tables are EXTERNAL_TABLE:

```bash
beeline -u 'jdbc:hive2://hiveserver2:10000/'
drop database if exists session_catalog_test cascade;
create database session_catalog_test;
use session_catalog_test;
SET hive.txn.manager=org.apache.hadoop.hive.ql.lockmgr.DbTxnManager;
SET hive.support.concurrency=true;
CREATE TABLE hive_insert_only_parquet (
  id INT,
  value STRING
)
  CLUSTERED BY(id) INTO 32 BUCKETS
  STORED AS PARQUET
  TBLPROPERTIES ('transactional'='true',
  'transactional_properties'='insert_only');
insert into hive_insert_only_parquet(id, value) values (1,'A');
CREATE TABLE hive_acid_orc (
  id INT,
  value STRING
)
  CLUSTERED BY(id) INTO 32 BUCKETS
  STORED AS ORC
  TBLPROPERTIES ('transactional'='true');
insert into hive_acid_orc(id, value) values (2,'B');
CREATE TABLE hive_normal_qarquet (
  id INT,
  value STRING
)
  STORED AS PARQUET;
insert into hive_normal_qarquet(id, value) values (3,'C');
desc formatted hive_insert_only_parquet;
desc formatted hive_acid_orc;
desc formatted hive_normal_qarquet;
select * from hive_insert_only_parquet;
select * from hive_acid_orc;
select * from hive_normal_qarquet;
```

`bash test/spark-with-iceberg-hive-session.sh`:

```sql
show databases;
-- databases: default, session_catalog_test;
use session_catalog_test;
-- empty, it's a bug
select * from hive_insert_only_parquet;
-- The table must be stored using an ACID compliant format (such as ORC), but select will find (6,'F'). Hive still (1,'A')
insert into hive_insert_only_parquet(id, value) values (6,'F');
select * from hive_insert_only_parquet;
-- empty, it's a bug
select * from hive_acid_orc;
-- insert succeed, but not exactly true. select will find (6,'F'), and Hive select will fail on `ava.io.IOException: java.lang.IllegalArgumentException: Bucket ID out of range: -1 (state=,code=1)`
insert into hive_acid_orc(id, value) values (5,'E');
select * from hive_acid_orc;

-- insert succeed, two rows: (4,'D'), (3,'C')
insert into hive_normal_qarquet(id, value) values (4,'D');
select * from hive_normal_qarquet;
```

So the different is:

- just hive_prod, you should `use hive_prod`, `spark_catalog` only default.
- hive_prod + hive session, hive_pord will be `Delegated SessionCatalog`, you can't use hive_prod, all databases in hive_prod are in spark_catalog.

desc formatted session_catalog_test.hive_insert_only_parquet;

### hive acid issues

We may get empty when selecting hive acid table.

The bug we met when spark read hive acid(select * from acid_table) before:

```log
MetaException(message:Your client does not appear to support insert-only tables. To skip capability checks, please set metastore.client.capability.check to false. This setting can be set globally, or on the client for the current metastore session. Note that this may lead to incorrect results, data loss, undefined behavior, etc. if your client is actually incompatible. You can also specify custom client capabilities via get_table_req API.)   Description  The server encountered an unexpected condition that prevented it from fulfilling the request.   Exception   javax.servlet.ServletException: javax.servlet.ServletException: MetaException(message:Your client does not appear to support insert-only tables. To skip capability checks, please set metastore.client.capability.check to false. This setting can be set globally, or on the client for the current metastore session. Note that this may lead to incorrect results, data loss, undefined behavior, etc. if your client is actually incompatible. You can also specify custom client capabilities via get_table_req API.) (libchurl.c:935)  (seg36 slice1 172.16.10.26:4000 pid=93248) (libchurl.c:935)
```

spark 3.2.1 + hive 3.1.2, acid works? iceberg hive catalog works? session catalog works?
Hive 3 dose not support java 11, needs java 8

check about spark with hive3.1.2 dependency:

openmldb/spark/bin/spark-sql -c spark.openmldb.sparksql=true -c spark.sql.hive.metastore.version=3.1.2 -c spark.sql.hive.metastore.jars=maven

empty too

openmldb/spark/bin/spark-sql -c spark.openmldb.sparksql=true -c spark.sql.hive.metastore.version=3.1.2 -c spark.sql.hive.metastore.jars=maven -c spark.sql.warehouse.dir=hdfs://namenode:19000/user/hive/warehouse

failed too

spark-3.5.0 bin/spark-sql -c spark.hadoop.hive.metastore.uris=thrift://hive-metastore:9083 other configs in spark/conf/hive-site.xml and core-site.xml
select * from db.hive_insert_only_parquet;
error: MetaException(message:Your client does not appear to support insert-only tables. To skip capability checks, please set metastore.client.capability.check to false. This setting can be set globally, or on the client for the current metastore session. Note that this may lead to incorrect results, data loss, undefined behavior, etc. if your client is actually incompatible. You can also specify custom client capabilities via get_table_req API.)

spark/jars:
-rw-r--r-- 1 huangwei staff  559K Jan 29 22:28 spark-hive-thriftserver_2.12-3.5.0.jar
-rw-r--r-- 1 huangwei staff  708K Jan 29 22:28 spark-hive_2.12-3.5.0.jar
-rw-r--r-- 1 huangwei staff  7.9M Jan 29 22:28 hive-metastore-2.3.9.jar
so still 2.3.9.

spark 3.5.0 can set to 3.1.3, spark 3.2.1 set to 3.1.2 <https://spark.apache.org/docs/3.5.0/sql-data-sources-hive-tables.html#interacting-with-different-versions-of-hive-metastore>

bin/spark-sql -c spark.openmldb.sparksql=true -c spark.sql.hive.metastore.version=3.1.3 -c spark.sql.hive.metastore.jars=maven -c spark.sql.warehouse.dir=hdfs://namenode:19000/user/hive/warehouse -c spark.hadoop.hive.metastore.uris=thrift://hive-metastore:9083

## Thanks

<https://github.com/adiii717/docker-container-ssh>

<https://github.com/big-data-europe/docker-hadoop/>

<https://github.com/tabular-io/iceberg-rest-image>
