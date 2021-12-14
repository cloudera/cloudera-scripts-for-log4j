#!/bin/bash
# CLOUDERA SCRIPTS FOR LOG4J
#
# (C) Cloudera, Inc. 2021. All rights reserved.
#
# Applicable Open Source License: Apache License 2.0
#
# CLOUDERA PROVIDES THIS CODE TO YOU WITHOUT WARRANTIES OF ANY KIND. CLOUDERA DISCLAIMS ANY AND ALL EXPRESS AND IMPLIED WARRANTIES WITH RESPECT TO THIS CODE, INCLUDING BUT NOT LIMITED TO IMPLIED WARRANTIES OF TITLE, NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. CLOUDERA IS NOT LIABLE TO YOU,  AND WILL NOT DEFEND, INDEMNIFY, NOR HOLD YOU HARMLESS FOR ANY CLAIMS ARISING FROM OR RELATED TO THE CODE. ND WITH RESPECT TO YOUR EXERCISE OF ANY RIGHTS GRANTED TO YOU FOR THE CODE, CLOUDERA IS NOT LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, PUNITIVE OR ONSEQUENTIAL DAMAGES INCLUDING, BUT NOT LIMITED TO, DAMAGES  RELATED TO LOST REVENUE, LOST PROFITS, LOSS OF INCOME, LOSS OF  BUSINESS ADVANTAGE OR UNAVAILABILITY, OR LOSS OR CORRUPTION OF DATA.
#
# --------------------------------------------------------------------------------------

BASEDIR=$(dirname "$0")
echo $BASEDIR

if [ -z "$SKIP_JAR" ]; then
  echo "Removing JNDI from jar files"
  $BASEDIR/hdp_support_scripts/delete_jndi.sh "$1" $2
else
  echo "Skipped patching .jar"
fi

if [ -z "$SKIP_HDFS" ]; then
  if ps -efww | grep org.apache.hadoop.hdfs.server.namenode.NameNode | grep -v grep  1>/dev/null 2>&1; then
    echo "Found an HDFS namenode on this host, removing JNDI from HDFS tar.gz files"
    $BASEDIR/hdp_support_scripts/patch_hdfs_tgz.sh "/hdp/apps/"
    $BASEDIR/hdp_support_scripts/patch_hdfs_tgz.sh "/user/"
  fi
else
  echo "Skipped patching .tar.gz in HDFS"
fi

if [ -n "$RUN_SCAN" ]; then
  echo "Running scan for missed JndiLookup classes. This may take a while."
  $BASEDIR/hdp_support_scripts/scan_jndi.sh "$1" $2
fi

