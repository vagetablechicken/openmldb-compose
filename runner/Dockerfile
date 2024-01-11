FROM openjdk:11.0.13-jre-slim-bullseye
# just runner machines, support sshd, just root user with openmldb docker user root, sbin can't support different user name

EXPOSE 22
# ref https://github.com/adiii717/docker-container-ssh/tree/master/ssh-keys
#RUN useradd -rm -d /home/nf2/ -s /bin/bash -g root -G sudo -u 1001 ubuntu
#USER ubuntu
#WORKDIR /home/ubuntu

RUN mkdir -p /root/.ssh/ && \
    chmod 0700 /root/.ssh  && \
    touch /root/.ssh/authorized_keys && \
    chmod 600 /root/.ssh/authorized_keys && \
    touch /root/.ssh/config && \
    chmod 600 /root/.ssh/config

COPY ssh-keys/ /keys/
#COPY sources.list /etc/apt/sources.list
RUN cat /keys/id_rsa.pub >> /root/.ssh/authorized_keys
RUN cat /keys/config >> /root/.ssh/config
# receiver should have rsync too
# You can test start without curl
RUN apt-get update && \
    apt-get install -y openssh-server vim rsync curl

USER root
ENTRYPOINT service ssh start && bash
