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

set -e -o pipefail

BASEDIR=$(dirname "$0")

hdfs_path=$1

if [ ! "$#" -eq 1 ]; then
   	echo "Invalid arguements. The argument must be a single HDFS directory."
	exit 1
fi

delete_jndi=$BASEDIR/delete_jndi.sh
if [ ! -f "$delete_jndi" ]; then
	echo "Patch script not found: $delete_jndi"
	exit 1
fi

patch_tgz=$BASEDIR/patch_tgz.sh
if [ ! -f "$patch_tgz" ]; then
        echo "Patch script is not found: $patch_tgz"
        exit 1
fi

keytab="/etc/security/keytabs/hdfs.headless.keytab"
if [ -z "$keytab" ]; then
        echo "Keytab file not found: $keytab"
        exit 0
fi

echo "Using $keytab to access HDFS"

principal=$(klist -kt $keytab | grep -v HTTP | tail -1 | awk '{print $4}')
if [ -z "$principal" ]; then
        echo "principal not found: $principal"
        exit 0
fi

kinit -kt $keytab $principal

for hdfs_file_path in $(hdfs dfs -ls -R $hdfs_path | awk '{print $8}')
do
  echo $hdfs_file_path

  if [[ $hdfs_file_path == *.tar.gz ]]; then
	  current_time=$(date "+%Y.%m.%d-%H.%M.%S")
	  echo "Current Time : $current_time"

	  local_path="/tmp/hdfs_tar_files.${current_time}"
	  rm -r -f $local_path
	  mkdir -p $local_path

	  echo "Downloading tar ball from HDFS path $hdfs_file_path to $local_path"
	  echo "Printing current HDFS file stats"
	  hdfs dfs -ls $hdfs_file_path
	  username=$(hdfs dfs -ls $hdfs_file_path | awk '{print $3":"$4}')
	  hdfs dfs -get $hdfs_file_path $local_path

	  hdfs_bc_path="/tmp/backup.${current_time}"

	  echo "Taking a backup of HDFS dir $hdfs_file_path to $hdfs_bc_path"
	  hdfs dfs -mkdir -p $hdfs_bc_path
	  hdfs dfs -cp -f  $hdfs_file_path $hdfs_bc_path

	  out="$(basename $local_path/*)"
	  local_full_path="${local_path}/${out}"

	  echo "Executing the log4j removal script"
	  $patch_tgz $local_full_path

	  echo "Completed executing log4j removal script and uploading $out to $hdfs_file_path"
	  hdfs dfs -copyFromLocal -f $local_full_path $hdfs_file_path
	  hdfs dfs -chown $username $hdfs_file_path

	  echo "Printing updated HDFS file stats"
	  hdfs dfs -ls $hdfs_file_path
  elif [[ $hdfs_file_path == *.jar ]]; then
	  current_time=$(date "+%Y.%m.%d-%H.%M.%S")
	  echo "Current Time : $current_time"

	  local_path="/tmp/hdfs_tar_files.${current_time}"
	  rm -r -f $local_path
	  mkdir -p $local_path

	  echo "Downloading tar ball from HDFS path $hdfs_file_path to $local_path"
	  echo "Printing current HDFS file stats"
	  hdfs dfs -ls $hdfs_file_path
	  username=$(hdfs dfs -ls $hdfs_file_path | awk '{print $3":"$4}')
	  hdfs dfs -get $hdfs_file_path $local_path

	  hdfs_bc_path="/tmp/backup.${current_time}"

	  echo "Taking a backup of HDFS dir $hdfs_file_path to $hdfs_bc_path"
	  hdfs dfs -mkdir -p $hdfs_bc_path
	  hdfs dfs -cp -f  $hdfs_file_path $hdfs_bc_path

	  out="$(basename $local_path/*)"
	  local_full_path="${local_path}/${out}"

	  echo "Executing the log4j removal script"
	  $delete_jndi $local_full_path

	  echo "Completed executing log4j removal script and uploading $out to $hdfs_file_path"
	  hdfs dfs -copyFromLocal -f $local_full_path $hdfs_file_path
	  hdfs dfs -chown $username $hdfs_file_path

	  echo "Printing updated HDFS file stats"
	  hdfs dfs -ls $hdfs_file_path
  fi
done

kdestroy
