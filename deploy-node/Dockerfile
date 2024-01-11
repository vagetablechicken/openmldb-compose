FROM 4pdosc/openmldb:0.8.4

COPY ssh-keys/ /keys/
# ADD sources.list /etc/apt/sources.list

RUN apt update && apt install -y ssh curl netcat
RUN mkdir -p /root/.ssh/ && touch /root/.ssh/config && chmod 600 /root/.ssh/config && cat /keys/config >> /root/.ssh/config
