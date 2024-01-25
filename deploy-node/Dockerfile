FROM 4pdosc/openmldb:0.8.4

COPY ssh-keys/ /keys/
# ADD sources.list /etc/apt/sources.list

# failed
# RUN echo "deb https://dl.bintray.com/wangzw/deb trusty contrib" | tee /etc/apt/sources.list.d/bintray-wangzw-deb.list install libhdfs3 libhdfs3-dev pip install hdfs3
RUN apt install -y apt-transport-https
RUN apt update && apt install -y ssh curl netcat 
RUN pip3 install pyspark==3.2.1 pyarrow

RUN mkdir -p /root/.ssh/ && touch /root/.ssh/config && chmod 600 /root/.ssh/config && cat /keys/config >> /root/.ssh/config

RUN echo "set mouse-=a" >> ~/.vimrc 
# add hadoop and hive client
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
# add to path
ENV PATH=$PATH:$HADOOP_HOME/bin:$HIVE_HOME/bin
