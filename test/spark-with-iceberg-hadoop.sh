#!/bin/bash
$SPARK_HOME/bin/spark-sql -c spark.openmldb.sparksql=true -c spark.sql.catalog.hadoop_prod=org.apache.iceberg.spark.SparkCatalog -c spark.sql.catalog.hadoop_prod.type=hadoop -c spark.sql.catalog.hadoop_prod.warehouse="hdfs://namenode:19000/user/hadoop_iceberg"
