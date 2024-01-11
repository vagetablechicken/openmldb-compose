# OpenMLDB Cluster

OpenMLDB with all components and hdfs service.

```
docker-compose build # build all images if you modify Dockerfile
docker-compose up -d
```

## test

test hdfs:
```
echo 'sc.parallelize(List( (1,"a"), (2,"b") )).toDF("key","value").write.mode("overwrite").option("header", "true").csv("hdfs://namenode:19000/tmp/shell-out")' | $SPARK_HOME/bin/spark-shell
```

then you can read:
```
echo 'spark.read.option("header", "true").csv("hdfs://namenode:19000/tmp/shell-out").show()' | $SPARK_HOME/bin/spark-shell
```

Debug hdfs:
TODO

Debug zk:
```
echo stat | nc openmldb-compose-zk-1 2181
```

To run openmldb test, scripts are in dir test/, run:
```
/work/openmldb/sbin/openmldb-cli.sh < test/test.sql
```
You can check it on hdfs:
echo 'spark.read.option("header", "true").csv("hdfs://namenode:19000/test/").show()' | $SPARK_HOME/bin/spark-shell

## Thanks

https://github.com/adiii717/docker-container-ssh

https://github.com/big-data-europe/docker-hadoop/
