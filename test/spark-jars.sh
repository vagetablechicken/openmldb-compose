#!/bin/bash
ssh openmldb-compose-tm-1 "rm -f /work/openmldb/spark/jars/openmldb-* && ls -l /work/openmldb/spark/jars/openmldb-*"
ssh openmldb-compose-tm-2 "rm -f /work/openmldb/spark/jars/openmldb-* && ls -l /work/openmldb/spark/jars/openmldb-*"
