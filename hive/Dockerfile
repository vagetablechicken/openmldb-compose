FROM 4pdosc/openmldb:0.8.4
# any java image is ok

RUN apt update && apt install -y curl netcat
RUN curl -L https://dlcdn.apache.org/hadoop/common/hadoop-3.3.6/hadoop-3.3.6.tar.gz -o /tmp/hadoop.tar.gz && \
    curl -L https://dlcdn.apache.org/hive/hive-4.0.0-beta-1/apache-hive-4.0.0-beta-1-bin.tar.gz -o /tmp/hive.tar.gz && \
    tar -xzf /tmp/hadoop.tar.gz -C /opt/ && \
    rm -rf /tmp/hadoop.tar.gz && \
    ln -s /opt/hadoop-3.3.6 /opt/hadoop && \
    tar -xzf /tmp/hive.tar.gz -C /opt/ && \
    rm -rf /tmp/hive.tar.gz && \
    ln -s /opt/apache-hive-4.0.0-beta-1-bin /opt/hive

# JAVA_HOME in openmldb:0.8.4 is /usr/local/openjdk-11
ENV HADOOP_HOME=/opt/hadoop
ENV HIVE_HOME=/opt/hive
ENV HADOOP_CONF_DIR=$HADOOP_HOME/etc/hadoop
