#!/bin/bash
source /work/test/funcs.sh
hdfs -mkdir -p /user/hadoop_iceberg/
hdfs -rm -r "/user/hadoop_iceberg/*"
$SPARK_HOME/bin/spark-sql --properties-file=/work/test/ice_hadoop.ini -c spark.openmldb.sparksql=true < /work/test/ice_hadoop_setup.sql
/work/openmldb/sbin/openmldb-cli.sh --interactive=false --spark_conf /work/test/ice_hadoop.ini < test/ice_hadoop_test.sql
$SPARK_HOME/bin/spark-sql --properties-file=/work/test/ice_hadoop.ini -c spark.openmldb.sparksql=true -e \
 "DESC FORMATTED hadoop_prod.nyc.taxis;SELECT * FROM hadoop_prod.nyc.taxis;DESC FORMATTED hadoop_prod.nyc.taxis_out;SELECT * FROM hadoop_prod.nyc.taxis_out;"