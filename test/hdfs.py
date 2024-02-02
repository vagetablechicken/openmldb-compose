from pyspark.sql import SparkSession
from pyspark.sql import SQLContext

# Create a SparkSession
spark = SparkSession.builder.appName("WriteToHDFS").getOrCreate()

data = [("Alice", 1), ("Bob", 2), ("Charlie", 3)]
df = spark.createDataFrame(data, ["Name", "Age"])
df.write.format("parquet").mode("overwrite").save("hdfs://namenode:19000/user/test/df.parquet")
sqlContext = SQLContext(spark.sparkContext)
read_df = sqlContext.read.format("parquet").load("hdfs://namenode:19000/user/test/df.parquet")
read_df.show()
