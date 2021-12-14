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

set -eu -o pipefail

shopt -s globstar
shopt -s nullglob 

BASEDIR=$(dirname "$0")

patch_tgz=$BASEDIR/patch_tgz.sh
if [ ! -f "$patch_tgz" ]; then
        echo "Patch script is not found: $patch_tgz"
        exit 1
fi

if ! command -v zip &> /dev/null; then
	echo "zip not found. zip is required to run this script."
	exit 1
fi

for targetdir in ${1:-/usr/hdp/current /usr/hdf/current /usr/lib /var/lib}
do
  echo "Running on '$targetdir'"

  backupdir=${2:-/opt/cloudera/log4shell-backup}
  mkdir -p "$backupdir"
  echo "Backing up files to '$backupdir'"

  for jarfile in $targetdir/**/*.jar; do
	if grep -q JndiLookup.class $jarfile; then
		# Backup file only if backup doesn't already exist
		mkdir -p "$backupdir/$(dirname $jarfile)"
		targetbackup="$backupdir/$jarfile.backup"
		if [ ! -f "$targetbackup" ]; then
			echo "Backing up to '$targetbackup'"
			cp -f "$jarfile" "$targetbackup"
		fi

		# Rip out class
		echo "Deleting JndiLookup.class from '$jarfile'"
		zip -q -d "$jarfile" \*/JndiLookup.class
	fi
  done
  
  for warfile in $targetdir/**/*.{war,nar}; do
    doZip=0
  
    rm -r -f /tmp/unzip_target
	mkdir /tmp/unzip_target
	set +e
	unzip -qq $warfile -d /tmp/unzip_target
	set -e
	  for jarfile in /tmp/unzip_target/**/*.jar; do
		if grep -q JndiLookup.class $jarfile; then
			# Backup file only if backup doesn't already exist
			mkdir -p "$backupdir/$(dirname $jarfile)"
			targetbackup="$backupdir/$jarfile.backup"
			if [ ! -f "$targetbackup" ]; then
				echo "Backing up to '$targetbackup'"
				cp -f "$jarfile" "$targetbackup"
			fi

			# Rip out class
			echo "Deleting JndiLookup.class from '$jarfile'"
			zip -q -d "$jarfile" \*/JndiLookup.class
			doZip=1
		fi
	  done

	if [ 1 -eq $doZip ]; then
	  echo "Updating '$warfile'"
	  pushd /tmp/unzip_target
	  zip -r -q $warfile .
	  popd
	fi
	
    rm -r -f /tmp/unzip_target
  done
  
  for tarfile in $targetdir/**/*.{tar.gz,tgz}; do
	if zgrep -q JndiLookup.class $tarfile; then
		$patch_tgz $tarfile
	fi
  done
done

echo "Run successful"

