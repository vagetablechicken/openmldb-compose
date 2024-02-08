#!/usr/bin/env bash

joblog() {
  set -o xtrace
  echo 'show joblog' "$@" ';' | /work/openmldb/sbin/openmldb-cli.sh
}

jobs() {
  set -o xtrace
  echo 'show jobs;' | /work/openmldb/sbin/openmldb-cli.sh
}

cli() {
  /work/openmldb/sbin/openmldb-cli.sh --interactive=false
}

# maintain
deploya() {
  /work/openmldb/sbin/deploy-all.sh
}

starta() {
  /work/openmldb/sbin/start-all.sh
}

stopt() {
  /work/openmldb/sbin/stop-taskmanagers.sh
}

startt() {
  /work/openmldb/sbin/start-taskmanagers.sh
}

tm_update() {
  deploya
  stopt
  startt
}

restarta() {
  /work/openmldb/sbin/stop-all.sh && /work/openmldb/sbin/clear-all.sh && starta
}

st() {
  openmldb_tool -c openmldb-compose-zk-1:2181/openmldb status --conn
}

ins() {
  openmldb_tool -c openmldb-compose-zk-1:2181/openmldb inspect
}

tm1() {
  ssh openmldb-compose-tm-1 "$@"
}

rm_spark() {
  # function arg check
  if [ "$#" -lt 1 ]; then
    echo "rm_spark <ssh-command>"
    return 1
  fi
  "$@" "rm -rf /work/openmldb/spark && ls -l /work/openmldb/spark"
}

hdfs() {
  hadoop fs -fs hdfs://namenode:9000 "$@"
}