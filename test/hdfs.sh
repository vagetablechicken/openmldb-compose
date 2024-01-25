#!/bin/bash
# HDFS test script

set -x

# script directory
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# read file from csv_data and write to hdfs
hadoop fs -mkdir -p /user/test
hadoop fs -put -f ${DIR}/csv_data/* /user/test/
hadoop fs -ls /user/test
