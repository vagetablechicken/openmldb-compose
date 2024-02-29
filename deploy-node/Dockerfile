FROM 4pdosc/openmldb:0.8.4
# don't build in here, build in root dir
COPY ssh-keys/ /keys/
ADD additions /additions
RUN if [ -f "/additions/sources.list" ] ; then cp /additions/sources.list /etc/apt/ ; fi
RUN if [ -f "/additions/pypi.txt" ] ; then pip config set global.index-url $(cat /additions/pypi.txt) ; fi
# hdfs tool failed, use raw hadoop binary
# RUN echo "deb https://dl.bintray.com/wangzw/deb trusty contrib" | tee /etc/apt/sources.list.d/bintray-wangzw-deb.list install libhdfs3 libhdfs3-dev pip install hdfs3
RUN apt update && apt install -y ssh curl netcat apt-transport-https less
RUN pip3 install pyspark==3.2.1 pyarrow pytest

RUN mkdir -p /root/.ssh/ && touch /root/.ssh/config && chmod 600 /root/.ssh/config && cat /keys/config >> /root/.ssh/config && chmod 600 /keys/id_rsa

RUN echo "set mouse-=a" >> ~/.vimrc

# add hadoop and hive client
ENV HADOOP_VERSION=3.3.6
ENV HIVE_VERSION=4.0.0-beta-1

RUN if [ !-f "/additions/hadoop-$HADOOP_VERSION.tar.gz" ] ; then curl -L https://mirror.sjtu.edu.cn/apache/hadoop/common/hadoop-$HADOOP_VERSION/hadoop-$HADOOP_VERSION.tar.gz -o /tmp/hadoop.tar.gz ; else cp /additions/hadoop-$HADOOP_VERSION.tar.gz /tmp/hadoop.tar.gz ; fi
RUN if [ !-f "/additions/apache-hive-$HIVE_VERSION-bin.tar.gz" ] ; then curl -L https://mirror.sjtu.edu.cn/apache/hive/hive-$HIVE_VERSION/apache-hive-$HIVE_VERSION-bin.tar.gz -o /tmp/hive.tar.gz ; else cp /additions/apache-hive-$HIVE_VERSION-bin.tar.gz /tmp/hive.tar.gz ; fi
RUN tar -xzf /tmp/hadoop.tar.gz -C /opt/ && \
    rm -rf /tmp/hadoop.tar.gz && \
    ln -s /opt/hadoop-$HADOOP_VERSION /opt/hadoop && \
    tar -xzf /tmp/hive.tar.gz -C /opt/ && \
    rm -rf /tmp/hive.tar.gz && \
    ln -s /opt/apache-hive-$HIVE_VERSION-bin /opt/hive

# JAVA_HOME in openmldb:0.8.4 is /usr/local/openjdk-11
ENV HADOOP_HOME=/opt/hadoop
ENV HIVE_HOME=/opt/hive
ENV HADOOP_CONF_DIR=$HADOOP_HOME/etc/hadoop
# add to path
ENV PATH=$PATH:$HADOOP_HOME/bin:$HIVE_HOME/bin
