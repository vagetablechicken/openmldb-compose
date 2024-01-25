#!/usr/bin/env bash

joblog() {
  set -o xtrace
  echo 'show joblog' "$@" ';' | /work/openmldb/sbin/openmldb-cli.sh
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

restarta() {
  /work/openmldb/sbin/stop-all.sh && /work/openmldb/sbin/clear-all.sh && starta
}

st() {
  openmldb_tool -c openmldb-compose-zk-1:2181/openmldb status --conn
}

tm1() {
  ssh openmldb-compose-tm-1
}
