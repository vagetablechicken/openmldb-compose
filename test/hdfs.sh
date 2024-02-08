#!/bin/bash
# HDFS test script

set -x

# script directory
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# read file from data and write to hdfs
source funcs.sh
hdfs -mkdir -p /user/test
hdfs -put -f ${DIR}/data/* /user/test/
hdfs -ls /user/test
