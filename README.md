# OpenMLDB Cluster

OpenMLDB with all components and hdfs service.

```
docker-compose build # build all images if you modify Dockerfile
docker-compose up -d
```

cleanup
docker volume ls | grep openmldb-compose | awk '{print$2}' | xargs docker volume rm


## compose

If hdfs is localhost, tm container can't access it. I add hdfs and hive as a service `hive-metastore` in docker-compose.yml.

spark should know it, add iceberg jar
```
spark need https://iceberg.apache.org/docs/latest/hive/ to use hive catalog. download iceberg-hive-runtime
use 1.4.2 cus iceberg-spark-runtime in spark jars is 1.4.2
wget https://repo1.maven.org/maven2/org/apache/iceberg/iceberg-hive-runtime/1.4.2/iceberg-hive-runtime-1.4.2.jar
cp iceberg-hive-runtime-1.4.2.jar $SPARK_HOME/jars
```
Or `spark.jars.packages=org.apache.iceberg:iceberg-spark-runtime-3.2_2.12:1.4.2;org.apache.iceberg:iceberg-hive-runtime:1.4.2`.

## test

test hdfs:
```
echo 'sc.parallelize(List( (1,"a"), (2,"b") )).toDF("key","value").write.mode("overwrite").option("header", "true").csv("hdfs://namenode:19000/tmp/shell-out")' | $SPARK_HOME/bin/spark-shell
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

## Hive

hive 4.0.0 failed:
```bash
export HIVE_VERSION=4.0.0-alpha-2
 docker run -d -p 9083:9083 --env SERVICE_NAME=metastore \
      --env DB_DRIVER=postgres -v $(pwd)/hive:/hive_custom_conf --env HIVE_CUSTOM_CONF_DIR=/hive_custom_conf \
      --name metastore apache/hive:${HIVE_VERSION}

 docker run -d -p 10000:10000 -p 10002:10002 --env SERVICE_NAME=hiveserver2 \
      --env SERVICE_OPTS="-Dhive.metastore.uris=thrift://metastore:9083" \
      --env IS_RESUME="true" \
      --name hiveserver2-standalone apache/hive:${HIVE_VERSION}
```

locahost start:
https://dlcdn.apache.org/hadoop/common/hadoop-3.3.6/hadoop-3.3.6.tar.gz
https://dlcdn.apache.org/hive/hive-4.0.0-beta-1/apache-hive-4.0.0-beta-1-bin.tar.gz

Hive uses Hadoop, so:

you must have Hadoop in your path, so we must install hive in hadoop env(client side, connect to hdfs cluster)
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

derby sucks, use postgres

Hive by default gets its configuration from <install-dir>/conf/hive-default.xml
The location of the Hive configuration directory can be changed by setting the HIVE_CONF_DIR environment variable.
Configuration variables can be changed by (re-)defining them in <install-dir>/conf/hive-site.xml

cp hive-site.xml $HIVE_HOME/conf
$HIVE_HOME/bin/schematool -dbType postgres -initSchema --verbose

$HIVE_HOME/bin/hiveserver2 & # server
$HIVE_HOME/bin/beeline -u jdbc:hive2:// # cli on server
$HIVE_HOME/bin/beeline -u jdbc:hive2://hive-metastore:10000 # cli on client

show databases; # one `default` db
```

spark-sql start way:
```
$SPARK_HOME/bin/spark-sql --properties-file test/spark.extra.ini -c spark.openmldb.sparksql=true
```

## Iceberg Test

Creation ref https://iceberg.apache.org/hive-quickstart/.

### Hive Catalog

you can cleanup the hive data by 
`docker-compose2 down hive-postgres hive-metastore && docker volume rm openmldb-compose_hive_postgres && docker-compose2 up -d`
cleanup: `docker exec deploy-node hadoop fs -rm -r "/user/hive/warehouse/*"` 

- Step 1: create database and iceberg table in hive
```
docker exec deploy-node hadoop fs -mkdir -p /user/hive/external_warehouse # store iceberg metadata
docker exec deploy-node hadoop fs -mkdir -p /user/hive/iceberg_storage # store iceberg data
```
iceberg hive catalog must set `spark.sql.catalog.hive_prod.warehouse=../user/hive/iceberg_storage` to create table. Or must use hive to create table.

spark jar is hive-metastore-2.3.9.jar, compatible with hive 4.0.0-beta-1 metastore service.
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
PARTITIONED BY (vendor_id) USING iceberg;
desc formatted taxis;
-- prepare for select out
CREATE TABLE taxis_out
(
  vendor_id bigint,
  trip_id bigint,
  trip_distance float,
  fare_amount double,
  store_and_fwd_flag string
)
PARTITIONED BY (vendor_id);
INSERT INTO taxis
VALUES (1, 1000371, 1.8, 15.32, 'N'), (2, 1000372, 2.5, 22.15, 'N'), (2, 1000373, 0.9, 9.01, 'N'), (1, 1000374, 8.4, 42.13, 'Y');
SELECT * FROM taxis;

desc formatted hive_prod.nyc.taxis;
select * from hive_prod.nyc.taxis;
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

### Session Catalog

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
CREATE TABLE acid_table (
  col1 INT,
  col2 STRING
)
STORED AS ORC
TBLPROPERTIES ('transactional'='true');
DESCRIBE FORMATTED default.acid_table;
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


## Thanks

https://github.com/adiii717/docker-container-ssh

https://github.com/big-data-europe/docker-hadoop/

https://github.com/tabular-io/iceberg-rest-image 
