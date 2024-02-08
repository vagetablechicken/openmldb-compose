#!/bin/bash
source /work/test/funcs.sh
hdfs -mkdir -p /user/hive/external_warehouse # store iceberg metadata?
hdfs -mkdir -p /user/hive/iceberg_storage # store iceberg data
# hdfs -rm -r "/user/hive/iceberg_storage/*" "/user/hive/external_warehouse*"
$SPARK_HOME/bin/spark-sql --properties-file=/work/test/ice_hive.ini -c spark.openmldb.sparksql=true < /work/test/ice_hive_setup.sql
/work/openmldb/sbin/openmldb-cli.sh --interactive=false --spark_conf /work/test/ice_hive.ini < test/ice_hive_test.sql
$SPARK_HOME/bin/spark-sql --properties-file=/work/test/ice_hive.ini -c spark.openmldb.sparksql=true -e \
 "DESC FORMATTED hive_prod.nyc.taxis;SELECT * FROM hive_prod.nyc.taxis;DESC FORMATTED hive_prod.nyc.taxis_out;SELECT * FROM hive_prod.nyc.taxis_out;"