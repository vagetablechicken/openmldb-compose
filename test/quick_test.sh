#!/bin/bash
# If you don't want to read test notes, just run this, check if any error in log
# docker-compose2 --env-file compose.env -f hadoop-compose.yml -f hive-compose.yml -f compose.yml -f ice-rest.yml up -d
set -ex
source /work/test/funcs.sh
pushd /work
st
echo "dir prepare" # no need to rm, cuz we always use `docker-compose down` and `hdfs -rm` to clean up
hdfs -mkdir -p /user/hive/external_warehouse # store iceberg metadata
hdfs -mkdir -p /user/hive/iceberg_storage # store iceberg data
hdfs -mkdir -p /user/iceberg/hadoop

echo "***** BASIC TEST *****"
bash test/basic_test.sh
echo "***** ICEBERG HIVE TEST *****"
$SPARK_HOME/bin/spark-sql --properties-file=/work/test/ice_hive.ini -c spark.openmldb.sparksql=true < /work/test/ice_hive_setup.sql
/work/openmldb/sbin/openmldb-cli.sh --interactive=false --spark_conf /work/test/ice_hive.ini < test/ice_hive_test.sql
$SPARK_HOME/bin/spark-sql --properties-file=/work/test/ice_hive.ini -c spark.openmldb.sparksql=true -e \
 "DESC FORMATTED hive_prod.nyc.taxis;SELECT * FROM hive_prod.nyc.taxis;DESC FORMATTED hive_prod.nyc.taxis_out;SELECT * FROM hive_prod.nyc.taxis_out;"
echo "***** ICEBERG HADOOP TEST *****"
$SPARK_HOME/bin/spark-sql --properties-file=/work/test/ice_hadoop.ini -c spark.openmldb.sparksql=true < /work/test/ice_hadoop_setup.sql
/work/openmldb/sbin/openmldb-cli.sh --interactive=false --spark_conf /work/test/ice_hadoop.ini < test/ice_hadoop_test.sql
$SPARK_HOME/bin/spark-sql --properties-file=/work/test/ice_hadoop.ini -c spark.openmldb.sparksql=true -e \
 "DESC FORMATTED hadoop_prod.nyc.taxis;SELECT * FROM hadoop_prod.nyc.taxis;DESC FORMATTED hadoop_prod.nyc.taxis_out;SELECT * FROM hadoop_prod.nyc.taxis_out;"
echo "***** ICEBERG REST TEST *****"
$SPARK_HOME/bin/spark-sql --properties-file=/work/test/ice_hive.ini -c spark.openmldb.sparksql=true < /work/test/ice_hive_setup.sql
/work/openmldb/sbin/openmldb-cli.sh --interactive=false --spark_conf /work/test/ice_rest.ini < /work/test/ice_rest_test.sql
$SPARK_HOME/bin/spark-sql --properties-file=/work/test/ice_rest.ini -c spark.openmldb.sparksql=true -e \
 "DESC FORMATTED rest_prod.nyc.taxis;SELECT * FROM rest_prod.nyc.taxis;DESC FORMATTED rest_prod.nyc.taxis_out;SELECT * FROM rest_prod.nyc.taxis_out;"
echo "***** ICEBERG HIVE SESSION TEST *****"
# beeline -u jdbc:hive2://hiveserver2:10000 -e "!run /work/test/hive_setup.hql" # already done in basic_test
$SPARK_HOME/bin/spark-submit --master local --class com._4paradigm.openmldb.batchjob.RunBatchAndShow --properties-file /work/test/ice_hive_session.ini -c spark.openmldb.sparksql=true /work/openmldb/taskmanager/lib/openmldb-batchjob-*.jar "SELECT * FROM nyc.taxis;"
# read hive table succeed(cuz `spark.sql.catalogImplementation=hive`)
$SPARK_HOME/bin/spark-submit --master local --class com._4paradigm.openmldb.batchjob.RunBatchAndShow --properties-file /work/test/ice_hive_session.ini -c spark.openmldb.sparksql=true /work/openmldb/taskmanager/lib/openmldb-batchjob-*.jar "SELECT * FROM basic_test.test;"
popd
