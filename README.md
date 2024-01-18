# OpenMLDB Cluster

OpenMLDB with all components and hdfs service.

```
docker-compose build # build all images if you modify Dockerfile
docker-compose up -d
```

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
$HIVE_HOME/bin/beeline -u jdbc:hive2:// #cli
show databases; # one `default` db

https://iceberg.apache.org/hive-quickstart/
hive way:
CREATE DATABASE nyc;
CREATE TABLE nyc.taxis
(
  trip_id bigint,
  trip_distance float,
  fare_amount double,
  store_and_fwd_flag string
)
PARTITIONED BY (vendor_id bigint) STORED BY ICEBERG;
CREATE TABLE nyc.taxis_out
(
  trip_id bigint,
  trip_distance float,
  fare_amount double,
  store_and_fwd_flag string
)
PARTITIONED BY (vendor_id bigint) STORED BY ICEBERG;
DESCRIBE formatted nyc.taxis;
INSERT INTO nyc.taxis VALUES (1, 1.0, 1.1, 'a', 11), (2, 2.0, 2.2, 'b', 22); # failed, why??
select * from nyc.taxis;

location will be `Location:                          | hdfs://localhost:19000/user/hive/warehouse/nyc.db/taxis`.

Notice that hdfs is localhost, tm container can't access it. I'll add hive as a service in docker-compose.yml.


$HIVE_HOME/bin/hive --service metastore # 9083


spark should know it, add iceberg jar

spark need https://iceberg.apache.org/docs/latest/hive/ to use hive catalog. download iceberg-hive-runtime
use 1.4.2 cus iceberg-spark-runtime in spark jars is 1.4.2
wget https://repo1.maven.org/maven2/org/apache/iceberg/iceberg-hive-runtime/1.4.2/iceberg-hive-runtime-1.4.2.jar
cp iceberg-hive-runtime-1.4.2.jar $SPARK_HOME/jars

hive uris way(make spark catalog be hive catalog):
select * from nyc.taxis;

diy catalog way:
desc hive_prod.nyc.taxis;
INSERT INTO hive_prod.nyc.taxis VALUES (1, 1.0, 1.1, 'a', 11), (2, 2.0, 2.2, 'b', 22); # succeed
select * from hive_prod.nyc.taxis;

test openmldb <-> iceberg(hive catalog): test/iceberg.sql

check spark on deploy-node container test/spark-with-iceberg.sh
docker exec -it hive-metastore /opt/hive/bin/beeline -u jdbc:hive2://


## Thanks

https://github.com/adiii717/docker-container-ssh

https://github.com/big-data-europe/docker-hadoop/
