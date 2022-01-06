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
platform=${3:-common}

if ! command -v zip &> /dev/null; then
	echo "zip not found. zip is required to run this script."
	exit 1
fi

if ! command -v unzip &> /dev/null; then
	echo "unzip not found. unzip is required to run this script."
	exit 1
fi

if ! command -v zgrep &> /dev/null; then
	echo "zgrep not found. zgrep is required to run this script."
	exit 1
fi

if [ -z "$SKIP_JAR" ]; then
  echo "Removing JNDI from jar files"
  $BASEDIR/hdp_support_scripts/delete_jndi.sh "$1" $2
else
  echo "Skipped patching .jar"
fi

if [ -z "$SKIP_HDFS" ]; then
  if [[ $platform == "common" ||  $platform == "ibm" ]]; then
    if ps -efww | grep org.apache.hadoop.hdfs.server.namenode.NameNode | grep -v grep  1>/dev/null 2>&1; then
      echo "Found an HDFS namenode on this host, removing JNDI from HDFS tar.gz files for platform='$platform'"
      keytab_file="hdfs.headless.keytab"
      keytab=$(find /etc/security/keytabs/ -type f -iname $keytab_file |tail -1)
      $BASEDIR/hdp_support_scripts/patch_hdfs_tgz.sh "/hdp/apps/" $keytab $2
      $BASEDIR/hdp_support_scripts/patch_hdfs_tgz.sh "/user/" $keytab $2
    fi
  elif [ $platform == "dell" ]; then
    if ps -efww | grep org.apache.hadoop.yarn.server.resourcemanager.ResourceManager | grep -v grep  1>/dev/null 2>&1; then
      echo "Found an Resourcemanager on this host, removing JNDI from HDFS tar.gz files for platform='$platform'"
      keytab_file="hdfs.headless.keytab"
      keytab=$(find /etc/security/keytabs/ -type f -iname $keytab_file |tail -1)
      if [[ -z "$keytab" || ! -s $keytab ]]; then
        echo "If this is a secure cluster, please ensure that /etc/security/keytabs/hdfs.headless.keytab is present for DELL."
      fi
      $BASEDIR/hdp_support_scripts/patch_hdfs_tgz.sh "/hdp/apps/" $keytab $2
      $BASEDIR/hdp_support_scripts/patch_hdfs_tgz.sh "/user/" $keytab $2
    fi
  fi
else
  echo "Skipped patching .tar.gz in HDFS"
fi

if [ -n "$RUN_SCAN" ]; then
  echo "Running scan for missed JndiLookup classes. This may take a while."
  $BASEDIR/hdp_support_scripts/scan_jndi.sh "$1" $2
fi

