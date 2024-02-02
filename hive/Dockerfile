FROM openjdk:11-jre
# any java image is ok
# 8 for hive 3.1.2
# 11 for hive 4.0.0-beta-1

ENV HADOOP_VERSION=3.3.6
ENV HIVE_VERSION=4.0.0-beta-1
#3.1.2

RUN apt update && apt install -y curl netcat vim procps net-tools
RUN curl -L https://dlcdn.apache.org/hadoop/common/hadoop-$HADOOP_VERSION/hadoop-$HADOOP_VERSION.tar.gz -o /tmp/hadoop.tar.gz && \
    curl -L https://dlcdn.apache.org/hive/hive-$HIVE_VERSION/apache-hive-$HIVE_VERSION-bin.tar.gz -o /tmp/hive.tar.gz && \
    tar -xzf /tmp/hadoop.tar.gz -C /opt/ && \
    rm -rf /tmp/hadoop.tar.gz && \
    ln -s /opt/hadoop-$HADOOP_VERSION /opt/hadoop && \
    tar -xzf /tmp/hive.tar.gz -C /opt/ && \
    rm -rf /tmp/hive.tar.gz && \
    ln -s /opt/apache-hive-$HIVE_VERSION-bin /opt/hive

ENV JAVA_HOME=/usr/local/openjdk-11
ENV HADOOP_HOME=/opt/hadoop
ENV HIVE_HOME=/opt/hive
ENV HADOOP_CONF_DIR=$HADOOP_HOME/etc/hadoop
ENV JVM_ARGS="-Xms10240m -Xmx10240m"
ENV PATH=$PATH:$HADOOP_HOME/bin:$HIVE_HOME/bin
