import pyspark

spark = pyspark.sql.SparkSession.builder \
    .appName("Spark Hive Example") \
    .config("spark.openmldb.sparksql", "true") \
    .enableHiveSupport() \
    .getOrCreate()

# .config("spark.hive.metastore.client.capability.check", "false") 
spark.sparkContext.setLogLevel("INFO")
configurations = spark.sparkContext.getConf().getAll()
for item in configurations:
    print(item)

spark.sql("show databases").show()
# spark.sql("show tables").show()

# spark.sql("set hive.metastore.client.capability.check=false")
# spark.sql("set hive.txn.manager=org.apache.hadoop.hive.ql.lockmgr.DbTxnManager;")
# spark.sql("set hive.support.concurrency=true;")
# spark.sql("select * from db.hive_insert_only_parquet").show()
spark.sql("drop database if exists pyspark_db cascade")
spark.sql("create database pyspark_db")
spark.sql("drop table if exists pyspark_db.pyspark_table")
# spark.sql("create table if not exists pyspark_table (key int, value string) using hive") # can't create hive table in remote hive metastore, location will be local file
# using dataframe save
df = spark.createDataFrame([(1, "one"), (2, "two")], ["key", "value"])
df.write.format("hive").saveAsTable("pyspark_db.pyspark_table")
spark.sql("desc formatted pyspark_db.pyspark_table").show(truncate=False)
spark.sql("select * from pyspark_db.pyspark_table").show()

# read by metastore, success, even no postgresql jar
# spark = pyspark.sql.SparkSession.builder \
#     .appName("Spark Hive Example") \
#     .config("spark.openmldb.sparksql", "true") \
#     .config("spark.hadoop.hive.metastore.uris", "thrift://metastore:9083") \
#     .enableHiveSupport() \
#     .getOrCreate()
# spark.sparkContext.setLogLevel("INFO")
# spark.sql("select * from pyspark_db.pyspark_table").show()
