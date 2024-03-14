import pandas as pd

# CREATE TABLE t1 (col1 int, std_time TIMESTAMP, INDEX(KEY=col1, TS=std_time)) OPTIONS(partitionnum=1, replicanum=1, storage_mode='HDD');
# CREATE TABLE t8 (col1 int, std_time TIMESTAMP, INDEX(KEY=col1, TS=std_time)) OPTIONS(partitionnum=8, replicanum=1, storage_mode='HDD');

# Create a list of 10 million rows, but cvt to spark dataframe is slow
# rows = []
# for i in range(1, 10000001):
#     rows.append((i, pd.Timestamp.now()))

# # Create a DataFrame with the specified schema
# df = pd.DataFrame(rows, columns=['col1', 'std_time'])
# print(df)

# Write the DataFrame to OpenMLDB
import pyspark
from pyspark.sql.functions import monotonically_increasing_id,lit
import datetime

spark = pyspark.sql.SparkSession.builder \
    .master("local[16]") \
    .config("spark.driver.memory", "16g") \
    .config("spark.openmldb.sparksql", "true") \
    .appName("Disk Table Test") \
    .enableHiveSupport() \
    .getOrCreate()
spark.sparkContext.setLogLevel("INFO")
# Create a DataFrame with 10 million rows and schema 'col1, std_time'
# NOTE: the type, id is long, cast to int
number_of_rows = 10000000
spark_df = spark.range(0, number_of_rows).select(monotonically_increasing_id().cast('int').alias('col1'),
                                           lit(datetime.datetime(1980,1,1)).alias('std_time'))
# Print the schema of the Spark DataFrame
spark_df.printSchema()
spark_df.show()

# Convert pandas DataFrame to Spark DataFrame
# spark_df = spark.createDataFrame(df)
# val writeOptions = Map(
#         "db" -> db,
#         "table" -> table,
#         "zkCluster" -> ctx.getConf.openmldbZkCluster,
#         "zkPath" -> ctx.getConf.openmldbZkRootPath,
#         "writerType" -> writeType,
#         "putIfAbsent" -> putIfAbsent.toString
#       )
spark_df.write.mode('append').options(
    db='db',
    table='t1',
    zkCluster='openmldb-compose-zk-1:2181',
    zkPath='/openmldb',
).format('openmldb').save()
