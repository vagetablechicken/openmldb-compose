import pyspark

builder = pyspark.sql.SparkSession.builder \
    .appName("Spark Hive Example") \
    .config("spark.openmldb.sparksql", "true")

# spark.sql.warehouse.dir will be loaded from hive-site.xml in spark/conf
# builder = builder.config("spark.sql.catalog.hive_prod.type", "hive") \
#     .config("spark.sql.catalog.hive_prod", "org.apache.iceberg.spark.SparkCatalog") \
#     .config("spark.sql.catalog.hive_prod.warehouse", "hdfs://namenode:9000/user/hive/iceberg_storage")

# hadoop iceberg table `nyc.taxis2` should be in spark_catalog(hive)
builder = builder.config("spark.sql.catalog.spark_catalog", "org.apache.iceberg.spark.SparkSessionCatalog").config("spark.sql.catalog.spark_catalog.type", "hadoop") \
    .config("spark.sql.catalog.spark_catalog.warehouse", "hdfs://namenode:9000/user/hadoop_iceberg")
builder = builder.config("spark.sql.catalog.hadoop_prod", "org.apache.iceberg.spark.SparkCatalog").config("spark.sql.catalog.hadoop_prod.type", "hadoop") \
    .config("spark.sql.catalog.hadoop_prod.warehouse", "hdfs://namenode:9000/user/hadoop_iceberg")
builder = builder.enableHiveSupport()

spark = builder.getOrCreate()
# .config("spark.hive.metastore.client.capability.check", "false") 
spark.sparkContext.setLogLevel("INFO")
configurations = spark.sparkContext.getConf().getAll()
for item in configurations:
    print(item)
# if no catalog, use database will report `Database 'hive_prod' not found`
# spark.sql("use hive_prod").show()
# spark.sql("show namespaces from hive_prod").show()
spark.sql("show namespaces from hadoop_prod").show()
spark.sql("show databases").show()
spark.sql("show tables").show()
# close
spark.sparkContext._gateway.close()
spark.stop()
