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
keytab=$2

if [ ! "$#" -eq 2 ]; then
	echo "Invalid arguements. The argument must be an HDFS directory and valid keytab file."
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

user_option=""
issecure="true"
if [[ -z "$keytab" || ! -s $keytab ]]; then
	echo "Keytab file is not found or is empty: $keytab. Considering this as a non-secure cluster deployment."
	issecure="false"
	user_option="sudo -u hdfs"
else
	echo "Using $keytab to access HDFS"

	principal=$(klist -kt $keytab | grep -v HTTP | tail -1 | awk '{print $4}')
	if [ -z "$principal" ]; then
			echo "principal not found: $principal"
			exit 0
	fi

	kinit -kt $keytab $principal
fi

tmpdir=${TMPDIR:-/tmp}
mkdir -p $tmpdir
echo "Using tmp directory '$tmpdir'"

for hdfs_file_path in $($user_option hdfs dfs -ls -R $hdfs_path | awk 'BEGIN {LAST=""} /^d/ {LAST=$8} /^-.*(jar|tar.gz)/ {if (LAST) { print LAST; } LAST=""}')
do
  echo $hdfs_file_path

  current_time=$(date "+%Y.%m.%d-%H.%M.%S")
  echo "Current Time : $current_time"

  local_path="$tmpdir/hdfs_tar_files.${current_time}"
  
  rm -r -f $local_path
  mkdir -p $local_path
  chmod 777 $local_path
  
  set +e
  $user_option hdfs dfs -get "${hdfs_file_path}/*.jar" $local_path
  ec=$?
  set -e
  
  if [ $ec -eq 0 ]; then
      d="2020-01-01 10:22:32"
	  touch -d "$d" $local_path/mark
	  touch -d "$d" $local_path/*
	  
	  $delete_jndi $local_path
	  
	  changed=()
	  for f in $(ls $local_path); do
		if [ $local_path/$f -nt $local_path/mark ]; then
		  changed+=($f)
		fi
	  done
	  
	  for f in ${changed[*]}; do
		output=$($user_option hdfs dfs -ls $hdfs_file_path/$f)
		username=$(echo $output | awk '{print $3":"$4}')
		permission=$(echo $output | awk '{print "u="gensub("-", "", "g", substr($1,2,3))",g="gensub("-", "", "g", substr($1,5,3))",o="gensub("-", "", "g", substr($1,8,3))}')
	    $user_option hdfs dfs -copyFromLocal -f $local_path/$f $hdfs_file_path/$f
		$user_option hdfs dfs -chown $username $hdfs_file_path/$f
		$user_option hdfs dfs -chmod $permission $hdfs_file_path/$f
	  done
  else
	echo "No files found. Skipping directory"
  fi

  local_path="$tmpdir/hdfs_tar_files.${current_time}"
  
  rm -r -f $local_path
  mkdir -p $local_path
  chmod 777 $local_path
  
  set +e
  $user_option hdfs dfs -get "${hdfs_file_path}/*.tar.gz" $local_path
  ec=$?
  set -e
  
  if [ $ec -eq 0 ]; then
		hdfs_bc_path="$tmpdir/backup.${current_time}"

		echo "Taking a backup of HDFS dir $hdfs_file_path to $hdfs_bc_path"
		$user_option hdfs dfs -mkdir -p $hdfs_bc_path
		$user_option hdfs dfs -cp -f  $hdfs_file_path/*.tar.gz $hdfs_bc_path
	
		for f in $(ls $local_path); do
			echo "Printing current HDFS file stats"
			output=$($user_option hdfs dfs -ls $hdfs_file_path/$f)
			echo $output
			username=$(echo $output | awk '{print $3":"$4}')
			permission=$(echo $output | awk '{print "u="gensub("-", "", "g", substr($1,2,3))",g="gensub("-", "", "g", substr($1,5,3))",o="gensub("-", "", "g", substr($1,8,3))}')

			local_full_path="${local_path}/${f}"

			echo "Executing the log4j removal script"
			$patch_tgz $local_full_path

			echo "Completed executing log4j removal script and uploading $f to $hdfs_file_path"
			$user_option hdfs dfs -copyFromLocal -f $local_full_path $hdfs_file_path/$f
			$user_option hdfs dfs -chown $username $hdfs_file_path/$f
			$user_option hdfs dfs -chmod $permission $hdfs_file_path/$f

			echo "Printing updated HDFS file stats"
			$user_option hdfs dfs -ls $hdfs_file_path/$f
		done
  else
	echo "No files found. Skipping directory"
  fi
done

if [ $issecure == "true" ]; then
	which kdestroy && kdestroy
fi
