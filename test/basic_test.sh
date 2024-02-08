#!/bin/bash
set -ex
# echo "hdfs test"
# echo 'sc.parallelize(List( (1,"a"), (2,"b") )).toDF("key","value").write.mode("overwrite").option("header", "true").csv("hdfs://namenode:9000/tmp/shell-out")' | $SPARK_HOME/bin/spark-shell
# echo 'spark.read.option("header", "true").csv("hdfs://namenode:9000/tmp/shell-out").show()' | $SPARK_HOME/bin/spark-shell

# echo "openmldb test"
# echo stat | nc openmldb-compose-zk-1 2181
# openmldb_tool -c openmldb-compose-zk-1:2181/openmldb status --conn
# openmldb_tool -c openmldb-compose-zk-1:2181/openmldb inspect
# echo "<-> hadoop"
# /work/openmldb/sbin/openmldb-cli.sh --interactive=false < test/hadoop.sql
# echo 'spark.read.option("header", "true").csv("hdfs://namenode:9000/tmp/openmldb-out").show()' | $SPARK_HOME/bin/spark-shell

echo "<-> hive"
beeline -u jdbc:hive2://hiveserver2:10000 -e "!run /work/test/hive_setup.hql"
/work/openmldb/sbin/openmldb-cli.sh --interactive=false --spark_conf /work/test/bultiin-hive.ini < test/hive.sql
beeline -u jdbc:hive2://hiveserver2:10000 -e "select * from basic_test.openmldb_write;"
/work/openmldb/sbin/openmldb-cli.sh --interactive=false --spark_conf /work/test/bultiin-hive.ini < test/hive_acid.sql
