# image of kafka-connect, use plugins contains openmldb connector

FROM bitnami/kafka:3.5.1-debian-11-r75

ARG DOWNLOAD_PLUGIN=true
ARG TF="kafka-connect-jdbc-10.5.0-SNAPSHOT-0.8.5.tgz"

RUN if [ ${DOWNLOAD_PLUGIN} ] ; then \
    mkdir -p /opt/connectors \
    && cd /opt/connectors \
    && curl -SLO https://openmldb.ai/download/kafka-connector/${TF} \
    && tar -xzf kafka-connect-jdbc-10.5.0-SNAPSHOT-0.8.5.tgz -C /opt/connectors \
    && rm -f kafka-connect-jdbc-10.5.0-SNAPSHOT-0.8.5.tgz \
    ; \
    fi
