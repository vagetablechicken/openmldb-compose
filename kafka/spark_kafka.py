from pyspark.sql import SparkSession

scala_version = '2.12'  # TODO: Ensure this is correct
spark_version = '3.2.1'
packages = [
    f'org.apache.spark:spark-sql-kafka-0-10_{scala_version}:{spark_version}',
    'org.apache.kafka:kafka-clients:3.2.0'
]

from requests.exceptions import JSONDecodeError
import requests
def http(url, method='post', ignore=False, http_code=200, **kwargs):
    ret = requests.request(method, url, **kwargs)
    assert ignore or ret.status_code == http_code, f'{ret.status_code} {ret.text}'
    try:
        print(ret.json())
        assert ignore or ret.json()['code'] == 0, ret.json()
    except JSONDecodeError:
        print("Response is not a JSON object", ret)

# read config from yml
yml='case.yml'
import yaml
with open(yml) as f:
    config = yaml.safe_load(f)
print(config)

id = config['run_case_id']
run_case = config['cases'][0] if not id else next(filter(lambda x: x['id'] == id, config['cases']))

print(f'run case: {run_case["id"]}')
# use apiserver for openmldb
# create database, table(optional, check auto.schema)
db = config['openmldb']['database']
api=f'http://{config["openmldb"]["apiserver.address"]}'

http(f'{api}/dbs/foo', json={'mode':'online','sql':f'create database if not exists {db};'})

kafka_append_conf = run_case['append_conf']
if 'auto.schema' in kafka_append_conf and kafka_append_conf['auto.schema'] == 'true':
    table = run_case['openmldb']['table']
    schema = run_case['openmldb']['schema']
    assert table, 'openmldb table is required'
    assert schema, 'table schema is required when table is not None'
    http(f'{api}/dbs/foo', json={'mode':'online','sql':f'create table if not exists {db}.{table} ({schema});'})
    http(f'{api}/dbs/foo', json={'mode':'online','sql':f'truncate table {db}.{table};'})
    http(f'{api}/dbs/foo', json={'mode':'online','sql':f'select count(*) from {db}.{table};'})

# kafka connector setup: drop topic(avoid legacy), recreate connector
import os
os.system('pip install kafka-python')
from kafka.admin import KafkaAdminClient
kafka_addr=config['kafka']['bootstrap.servers']
connect_addr=config['kafka']['connect.listeners']
admin_client = KafkaAdminClient(bootstrap_servers=[kafka_addr])

topic = kafka_append_conf['topics'] # only one
connector_conf = config['common_connector_conf']
connector_conf.update(kafka_append_conf)
connector = kafka_append_conf['name']

print(topic, connector, connector_conf)

# delete connector first, to avoid topic delete failed
print('delete connector')
http(f'{connect_addr}/connectors/{connector}', method='delete', ignore=True)

print(f'recreate topic {topic}')
from kafka.errors import UnknownTopicOrPartitionError
try:
    # async deletion
    dr = admin_client.delete_topics(topics=[topic])
    import time
    time.sleep(3)
    print("Topic Deleted Successfully")
except UnknownTopicOrPartitionError as e:
    print("Topic Doesn't Exist")
except Exception as e:
    print(e)

# create topic with partition num
from kafka.admin import NewTopic
part_num = config['kafka']['topic.partitions']
try:
    admin_client.create_topics(new_topics=[NewTopic(name=topic, num_partitions=part_num, replication_factor=1)], validate_only=False)
    print("Topic Created Successfully")
except Exception as e:
    print(e)

# check topic
tp = admin_client.describe_topics([topic])
print(tp)

print('create connector')
http(f'{connect_addr}/connectors', json={'name':connector, 'config':connector_conf}, http_code=201, ignore=True)

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
    .option("kafka.bootstrap.servers", kafka_addr)\
    .option("topic", topic)\
    .save()
