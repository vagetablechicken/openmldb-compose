#!/bin/bash
# connect log is in kafka-connect /opt/bitnami/kafka/logs/connect.log
# https://kafka.apache.org/documentation/#connect_rest
# topic use admin, java or in kafka dir
./bin/kafka-topics.sh --create --topic topic1 --bootstrap-server localhost:9092
./bin/kafka-topics.sh --describe --topic topic1 --bootstrap-server localhost:9092

curl -X POST -H "Content-Type: application/json" http://kafka-connect:8083/connectors -d '{
    "name": "test-connector",
    "config": {
    "connector.class": "io.confluent.connect.jdbc.JdbcSinkConnector",
    "tasks.max": "1",
    "connection.url": "jdbc:openmldb:///kafka_test?zk=openmldb-compose-zk-1:2181&zkPath=/openmldb",
    "topics": "topic1",
    "name": "test-connector",
    "auto.create": "true",
    "value.converter": "org.apache.kafka.connect.json.JsonConverter",
    "value.converter.schemas.enable": "true"
    }
}'

# get error msg if insert error
curl http://kafka-connect:8083/connectors/test-connector/status
# 当有一条出错后，status展示错误Exiting WorkerSinkTask due to unrecoverable exception.，再发消息也不会有效，这是unrecoverable的。
# restart task/connector也不会有效，task依旧failed，需要restart task，这样topic内历史的消息都会被写入。（得保证是消息正确，只是别的配置错误，比如openmldb没有建库）
curl -X POST http://kafka-connect:8083/connectors/test-connector/tasks/0/restart
