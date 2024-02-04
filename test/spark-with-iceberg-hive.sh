#!/bin/bash
#!/bin/bash
$SPARK_HOME/bin/spark-sql -c spark.openmldb.sparksql=true -c spark.sql.catalog.hive_prod=org.apache.iceberg.spark.SparkSessionCatalog \
 -c spark.sql.catalog.hive_prod.type=hive -c spark.sql.catalog.hive_prod.uri=thrift://metastore:9083 \
 -c spark.sql.catalog.hive_prod.warehouse=hdfs://namenode:9000foo/user/hive/iceberg_storage -c spark.sql.catalogImplementation=in-memory