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

TODO 
hive uris way(make spark_catalog be hive catalog):
select * from nyc.taxis;
hive ACID

## Thanks

https://github.com/adiii717/docker-container-ssh

https://github.com/big-data-europe/docker-hadoop/

https://github.com/tabular-io/iceberg-rest-image 
