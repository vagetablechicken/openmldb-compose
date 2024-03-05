from pyspark.sql import SparkSession

scala_version = '2.12'  # TODO: Ensure this is correct
spark_version = '3.2.1'
packages = [
    f'org.apache.spark:spark-sql-kafka-0-10_{scala_version}:{spark_version}',
    'org.apache.kafka:kafka-clients:3.2.0'
]
spark = SparkSession.builder\
   .master("local[16]")\
   .config("spark.driver.memory", "16g") \
   .appName("kafka-example")\
   .config("spark.jars.packages", ",".join(packages))\
   .config("spark.jars.ivySettings", "file:///work/ext/ivysettings.xml")\
   .getOrCreate()
spark.sparkContext.setLogLevel("INFO")
# Read all lines into a single value dataframe  with column 'value'
# TODO: Replace with real file. 
# better to set schema when read csv # TODO attributed time
df = spark.read.format('csv').option('header', 'true')\
    .schema("ip int,app int,device int,os int,channel int,click_time timestamp,attributed_time timestamp,is_attributed int")\
    .load('file:///work/ext/jmh/test/train.csv')
# timestamp to int ms, ignore null(set 0) for temp
from pyspark.sql.functions import unix_timestamp
df = df.withColumn('click_time', unix_timestamp('click_time')*1000).withColumn('attributed_time', unix_timestamp('attributed_time')*1000)
df.show()

# TODO: Remove the file header, if it exists
schema = df.schema
# get column names list
columns = schema.names
print(columns)
# make a row to be a json string
# df = spark.createDataFrame(df.toJSON().map(lambda x:[x]),'json STRING')
# df.show()
# print rdd
# from pyspark.sql.types import StructType,StructField, StringType
# spark.createDataFrame(rdd, schema=StructType([StructField("value", StringType())])).show()

# Write
from pyspark.sql.functions import *
from pyspark.sql.types import StringType
# key can be null, value is json, not string?. connector can handle this case
# df.select(to_json(struct(df.columns)).alias("value"))\
df = df.select(to_json(struct(col("*"))).alias("value")).withColumn("key", lit(None).cast(StringType()))
df.show(truncate=False)
df.select('key','value').write.format("kafka")\
    .option("kafka.bootstrap.servers", "kafka:9092")\
    .option("topic", "auto_schema")\
    .save()
