ARG DEPLOY_NODE_IMAGE=4pdosc/openmldb:0.8.5
FROM ${DEPLOY_NODE_IMAGE}
# don't build in here, build in root dir
COPY ssh-keys/ /keys/
COPY additions/ /additions/
RUN if [ -f "/additions/sources.list" ] ; then cp /additions/sources.list /etc/apt/ ; fi
RUN if [ -f "/additions/pypi.txt" ] ; then pip config set global.index-url $(cat /additions/pypi.txt) ; fi
# hdfs tool failed, use raw hadoop binary
# RUN echo "deb https://dl.bintray.com/wangzw/deb trusty contrib" | tee /etc/apt/sources.list.d/bintray-wangzw-deb.list install libhdfs3 libhdfs3-dev pip install hdfs3
RUN apt update
# may failed on install ssh(openssh-server)
RUN apt install -y ssh curl netcat apt-transport-https less putils-ping
RUN pip3 install pyspark==3.2.1 pyarrow pytest

RUN mkdir -p /root/.ssh/ && touch /root/.ssh/config && chmod 600 /root/.ssh/config && cat /keys/config >> /root/.ssh/config && chmod 600 /keys/id_rsa

RUN echo "set mouse-=a" >> ~/.vimrc

# add hadoop and hive client, hadoop is stable
ENV HADOOP_VERSION=3.3.6
ARG HIVE_VERSION=4.0.0-beta-1

RUN if [ ! -f "/additions/hadoop-$HADOOP_VERSION.tar.gz" ] ; then curl -L https://mirror.sjtu.edu.cn/apache/hadoop/common/hadoop-$HADOOP_VERSION/hadoop-$HADOOP_VERSION.tar.gz -o /tmp/hadoop.tar.gz ; else mv /additions/hadoop-$HADOOP_VERSION.tar.gz /tmp/hadoop.tar.gz ; fi
RUN tar -xzf /tmp/hadoop.tar.gz -C /opt/ && \
    rm -rf /tmp/hadoop.tar.gz && \
    ln -s /opt/hadoop-$HADOOP_VERSION /opt/hadoop
RUN if [ ! -f "/additions/apache-hive-$HIVE_VERSION-bin.tar.gz" ] ; then curl -L https://mirror.sjtu.edu.cn/apache/hive/hive-$HIVE_VERSION/apache-hive-$HIVE_VERSION-bin.tar.gz -o /tmp/hive.tar.gz ; else mv /additions/apache-hive-$HIVE_VERSION-bin.tar.gz /tmp/hive.tar.gz ; fi
RUN tar -xzf /tmp/hive.tar.gz -C /opt/ && \
    rm -rf /tmp/hive.tar.gz && \
    ln -s /opt/apache-hive-$HIVE_VERSION-bin /opt/hive

ENV HADOOP_HOME=/opt/hadoop
ENV HIVE_HOME=/opt/hive
ENV HADOOP_CONF_DIR=$HADOOP_HOME/etc/hadoop
ENV JAVA_HOME=/usr/local/openjdk-11
# add to path
ENV PATH=$PATH:$HADOOP_HOME/bin:$HIVE_HOME/bin:$JAVA_HOME/bin
ENV SPARK_HOME=/work/openmldb/spark
WORKDIR /work
