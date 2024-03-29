import pandas as pd

# CREATE TABLE db.t1 (col1 int, std_time TIMESTAMP, INDEX(KEY=col1, TS=std_time, ttl_type=latest, ttl=1)) OPTIONS(partitionnum=1, replicanum=1, storage_mode='HDD');
# CREATE TABLE db.t8 (col1 int, std_time TIMESTAMP, INDEX(KEY=col1, TS=std_time, ttl_type=latest, ttl=1)) OPTIONS(partitionnum=8, replicanum=1, storage_mode='HDD');

# Write the DataFrame to OpenMLDB
import pyspark
from pyspark.sql.functions import col,lit,monotonically_increasing_id
import datetime

spark = pyspark.sql.SparkSession.builder \
    .master("local[16]") \
    .config("spark.driver.memory", "16g") \
    .config("spark.openmldb.sparksql", "true") \
    .appName("Disk Table Test") \
    .enableHiveSupport() \
    .getOrCreate()
spark.sparkContext.setLogLevel("INFO")

def test_type_mismatch():
    # CREATE TABLE IF NOT EXISTS db.types (c1 int16,c2 int32,c3 int64,c4 float,c5 double,c6 bool,c7 string,c8 date,c9 timestamp);
    # test spark write int to openmldb long
    number_of_rows = 10
    # if no overflow(when insert, it will cast), it's ok to write long to openmldb int16
    # if overflow: long->openmldb int16/smallint ` Casting 100000000000000 to smallint causes overflow`
    # Cannot safely cast 'c6': int to boolean even just 0,1
    # monotonically_increasing_id cast to long and then dataframe write, it may get a large number, cast to int overflow, so write failed
    # spark_df = spark.range(0, number_of_rows).select(lit('100').cast('smallint').alias('c1'),
    #                                                 # monotonically_increasing_id().cast('long').alias('c2'),
    #                                                 lit('10000000').cast('long').alias('c2'),
    #                                                 lit('1').cast('long').alias('c3'),
    #                                                 lit('1').cast('float').alias('c4'),
    #                                                 lit('1').cast('double').alias('c5'),
    #                                                 lit('true').cast('boolean').alias('c6'),
    #                                                 lit('hello').alias('c7'),
    #                                                 lit(datetime.date(1980,1,1)).alias('c8'),
    #                                                 lit(datetime.datetime(1980,1,1)).alias('c9'))
    
    # to check real data, use data mocker, 
    # python3 ~/OpenMLDB/demo/usability_testing/data_mocker.py -s "c1 int16,c2 int32,c3 int64,c4 float,c5 double,c6 bool,c7 string,c8 date,c9 timestamp" -o data -nf 10 -n 1000000 -f parquet
    spark_df = spark.read.parquet('data/*.parquet')
    # then cast column types whatever you want
    # lit('1000000000000').cast('int') will get null, don't test it
    spark_df = spark_df.withColumn('c1', col('c1').cast('long').alias('c1')) \
        .withColumn('c2', col('c2').cast('long').alias('c2')) \
        .withColumn('c4', col('c4').cast('double').alias('c4'))
    spark_df.show()
    spark_df.printSchema()
    print(spark_df.count())
    spark_df.write.mode('append').options(
        db='db',
        table='types',
        zkCluster='openmldb-compose-zk-1:2181',
        zkPath='/openmldb',
    ).format('openmldb').save()

# test_type_mismatch()

# Create a DataFrame with 10 million rows and schema 'col1, std_time'
# NOTE: the type, id is long, cast to int
number_of_rows = 30000000
# monotically_increasing_id() may get the same id when write in multi-thread?
# use list to create 
# spark_df = spark.sparkContext.parallelize([[i, datetime.datetime(1980,1,1)] for i in range(number_of_rows)]).toDF(("col1", "std_time"))
# spark_df = spark.range(0, number_of_rows).select(monotonically_increasing_id().cast('int').alias('col1'),
#                                            lit(datetime.datetime(1980,1,1)).alias('std_time'))

# Create a list of 10 million rows, but cvt to spark dataframe is slow
rows = [[str(i), datetime.datetime.now()] for i in range(number_of_rows)]

# Create a DataFrame with the specified schema
df = pd.DataFrame(rows, columns=['ibb_id', 'std_time'])
# Convert pandas DataFrame to Spark DataFrame
spark_df = spark.createDataFrame(df)

# Print the schema of the Spark DataFrame
spark_df.printSchema()
# check will be slow
# spark_df.show()
# print(spark_df.count())

# val writeOptions = Map(
#         "db" -> db,
#         "table" -> table,
#         "zkCluster" -> ctx.getConf.openmldbZkCluster,
#         "zkPath" -> ctx.getConf.openmldbZkRootPath,
#         "writerType" -> writeType,
#         "putIfAbsent" -> putIfAbsent.toString
#       )
spark_df.limit(100000).write.mode('append').options(
    db='db',
    table='game',
    zkCluster='openmldb-compose-zk-1:2181',
    zkPath='/openmldb',
).format('openmldb').save()

# user table is different schema, just column rename
spark_df.withColumnRenamed('ibb_id','ubb_gaid').mode('append').options(
    db='db',
    table='user',
    zkCluster='openmldb-compose-zk-1:2181',
    zkPath='/openmldb',
).format('openmldb').save()

# TODO: why write to disk table t1, count(*) = 625000? should be 10000000? data by monotonically_increasing_id is wrong.
# write multiple times(update), and check online select latency(just one row per key cuz lat 1, so it will be one row)
