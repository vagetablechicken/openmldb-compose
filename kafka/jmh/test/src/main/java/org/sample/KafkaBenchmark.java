/*
 * Copyright (c) 2014, Oracle America, Inc.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 *  * Redistributions of source code must retain the above copyright notice,
 *    this list of conditions and the following disclaimer.
 *
 *  * Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 *  * Neither the name of Oracle nor the names of its contributors may be used
 *    to endorse or promote products derived from this software without
 *    specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
 * THE POSSIBILITY OF SUCH DAMAGE.
 */

package org.sample;

import java.io.IOException;
import java.io.InputStream;
import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.Properties;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.TimeUnit;
import java.util.stream.Collectors;
import java.io.BufferedReader;
import java.io.FileReader;

import org.openjdk.jmh.annotations.*;
import org.openjdk.jmh.runner.*;
import org.openjdk.jmh.runner.options.*;

import lombok.extern.slf4j.Slf4j;
import com.google.common.base.Preconditions;
import lombok.Data;

import org.yaml.snakeyaml.Yaml;
import com.google.gson.Gson;

import org.apache.kafka.clients.admin.Admin;
import org.apache.kafka.clients.admin.DeleteTopicsResult;
import org.apache.kafka.clients.producer.KafkaProducer;
import org.apache.kafka.clients.producer.Producer;
import org.apache.kafka.clients.producer.ProducerRecord;

@Slf4j
@Fork(value = 1)
@BenchmarkMode(Mode.All)
@OutputTimeUnit(TimeUnit.MILLISECONDS) // local test may use micro
@Warmup(iterations = 1)
public class KafkaBenchmark {
  @Data
  @State(Scope.Benchmark)
  @Slf4j
  public static class KafkaState {
    private Map<String, Object> configMap;
    private Map<String, Object> caseMap;
    private String caseId;

    private Properties kafkaProperties;
    private Properties producerProperties;
    private String topicName;
    private Map<String, Object> connectConf;

    private String apiserverAddr;
    private String openmldbDBName;

    Producer<String, String> producer;
    JsonRecordGenerator source;

    @SuppressWarnings("unchecked")
    @Setup
    public void setUp() throws Exception {
      // load config file
      Yaml yaml = new Yaml();
      InputStream inputStream = KafkaState.class.getClassLoader().getResourceAsStream("case.yml");
      configMap = yaml.load(inputStream);

      Map<String, Object> kafka = (Map<String, Object>) configMap.get("kafka");
      // admin client needs bootstrap.servers
      // connect client needs connect.listeners
      kafkaProperties = new Properties();
      kafkaProperties.setProperty("bootstrap.servers", kafka.get("bootstrap.servers").toString());
      kafkaProperties.setProperty("connect.listeners", kafka.get("connect.listeners").toString());
      producerProperties = new Properties();
      producerProperties.setProperty(
          "bootstrap.servers", kafkaProperties.getProperty("bootstrap.servers"));
      // a map
      ((Map<String, String>) kafka.get("producer.properties"))
          .forEach((k, v) -> producerProperties.setProperty(k, v));

      // read openmldb apiserver for admin
      Map<String, String> openmldb = (Map<String, String>) configMap.get("openmldb");
      apiserverAddr = openmldb.get("apiserver.address");
      Preconditions.checkArgument(apiserverAddr != null, "apiserver.address is not set");
      log.info("kafka properties: {}, producer {}, openmldb apiserver: {}", kafkaProperties,
          producerProperties, apiserverAddr);
      // TODO(hw): kafka test cluster
      // https://mvnrepository.com/artifact/org.testcontainers/kafka

      // case.yml have multi cases(a list), run id is run_case_id, run first if empty
      String caseId = (String) configMap.get("run_case_id");
      List<Object> cases = (List<Object>) configMap.get("cases");
      log.info("cases {}, run caseId {}",
          cases.stream().map(c -> ((Map<String, Object>) c).get("id")).collect(Collectors.toList()),
          caseId);
      if (caseId == null || caseId.isEmpty()) {
        caseMap = (Map<String, Object>) cases.get(0);
      } else {
        caseMap = (Map<String, Object>) cases.stream()
                      .filter(c -> ((String) ((Map<String, Object>) c).get("id")).equals(caseId))
                      .findFirst()
                      .orElse(null);
      }
      Preconditions.checkState(caseMap != null, "case not found");
      // prepare connector and source data
      recreateTopic();
      createConnector();
      prepareOpenMLDB();
      prepareSource();
      createProducer();
    }
    private void recreateTopic() throws Exception {
      // create a topic in kafka TODO(hw): topics is fine?
      topicName = (String) ((Map<String, Object>) caseMap.get("append_conf")).get("topics");
      // only support one topic
      try (Admin admin = Admin.create(kafkaProperties)) {
        // deleteTopics first to avoid extra data in topic
        DeleteTopicsResult result = admin.deleteTopics(Collections.singleton(topicName));
        result.all().get();
        log.info("current kafka topics: {}",
            admin.listTopics().names().get().stream().collect(Collectors.toList()));
        // just let connector to create topics
      } catch (ExecutionException e) {
        // get delete result failed, don't abort
        log.warn("be careful, topic recreate may failed: {}", e.getMessage());
      } catch (InterruptedException e) {
        log.info("topic {} recreate failed, {}", topicName, e.getMessage());
        throw e;
      }
    }

    @SuppressWarnings("unchecked")
    private void createConnector() {
      // create a sink connector to OpenMLDB by http api
      Map<String, Object> appendConf = (Map<String, Object>) caseMap.get("append_conf");
      Map<String, Object> commonConf = (Map<String, Object>) configMap.get("common_connector_conf");
      // use append to override common
      connectConf = commonConf;
      connectConf.putAll(appendConf);
      String config = new Gson().toJson(connectConf);
      log.info("config {}", config);

      // when no topic, create the connector will create the topic, it's ok in test

      // read connector name from file
      String connectorName = (String) connectConf.get("name");
      // delete to avoid conflict
      try {
        Utils.kafkaConnectorDelete(Utils.kafkaConnectorUrl(kafkaProperties, connectorName));
      } catch (Exception e) {
        log.info("delete connector simple-connector failed(it's ok if not exists): {}", e.getMessage());
      }

      try {
        String createJson = "{\"name\":\"" + connectorName + "\",\"config\": " + config + "}";
        Utils.kafkaConnectorCreate(Utils.kafkaConnectorUrl(kafkaProperties, ""), createJson);
      } catch (IOException e) {
        e.printStackTrace();
      }
    }

    private void prepareOpenMLDB() throws Exception {
      String jdbcUrl = (String) connectConf.get("connection.url");
      // get dbname from url jdbc:openmldb:///<db>?
      String dbName = jdbcUrl.substring(17, jdbcUrl.lastIndexOf("?"));
      // ensure openmldb db exists
      Utils.apiserverQuery(apiserverAddr, "foo", "CREATE DATABASE IF NOT EXISTS " + dbName);

      // just drop test table to avoid unexpected data, if no openmldb_ddl, kafka
      // connector will create table automatically
      @SuppressWarnings("unchecked")
      String testTable = (String) ((Map<String, Object>) caseMap.get("expect")).get("table");
      // don't handle drop result, table may not exists before
      Utils.apiserverQuery(apiserverAddr, dbName, "DROP TABLE " + testTable);
      // check no table here
      Preconditions.checkState(
          Utils.apiserverTableExists(apiserverAddr, dbName, testTable) == false, "table exists");
      String createDDL = (String) caseMap.get("openmldb_ddl");
      if (createDDL != null) {
        // create table in OpenMLDB
        String ret = Utils.apiserverQuery(apiserverAddr, dbName, createDDL);
        log.info("create table ret: {}", ret);
      } else {
        String autoCreate = (String) connectConf.get("auto.create");
        Preconditions.checkArgument(autoCreate != null && autoCreate == "true",
            "no openmldb_ddl and auto.create is not true");
      }
    }
    public class JsonRecordGenerator {
      private List<String> filePaths;
      private int i;
      private BufferedReader br;
      private List<String> header; // TODO: record string(values with comma) to json map { col: value }

      public JsonRecordGenerator(List<String> filePaths) throws Exception {
        this.filePaths = filePaths;
        Preconditions.checkArgument(!filePaths.isEmpty(), "filePaths is empty");
        this.i = 0;
        // only support csv style
        this.br = new BufferedReader(new FileReader(filePaths.get(i)));
      }

      public String next() throws Exception {
        // read from file and return a json map { col: value }
        String line;
        if ((line = br.readLine()) == null) {
          // read next file
          br.close();
          i++;
          Preconditions.checkState(i < filePaths.size(), "no more file to read");
          br = new BufferedReader(new FileReader(filePaths.get(i)));
          line = br.readLine();
          if (line == null) {
            throw new IOException("file is empty");
          }
        }
        return new Gson().toJson(line);
      }
    }
    void prepareSource() throws Exception {
      // prepare source data
      // only support json style
      @SuppressWarnings("unchecked")
      List<String> paths = (List<String>) caseMap.get("files");
      source = new JsonRecordGenerator(paths);
    }
    void createProducer() {
      producer = new KafkaProducer<>(producerProperties);
    }
  }
  @Benchmark
  public void produce(KafkaState state) throws Exception {
    // produce one message(json) and send to kafka
    String record = state.getSource().next();
    if (record == null) {
      throw new RuntimeException("break test");
    }
    state.getProducer().send(
        new ProducerRecord<>(state.getTopicName(), null, record), (event, ex) -> {
          if (ex != null)
            ex.printStackTrace();
          // else
          //   log.info("Produced event to topic {}: event {}", state.getTopicName(), event.offset()); // not a good idea when insert large data
        });
  }

  public static void main(String[] args) throws RunnerException {
    Options opt =
        new OptionsBuilder().include(KafkaBenchmark.class.getSimpleName()).forks(1).build();

    new Runner(opt).run();
  }
}
