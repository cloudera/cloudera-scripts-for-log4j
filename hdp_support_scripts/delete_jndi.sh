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

BASEDIR=$(dirname "$0")
backup_dir=$2

#tmpdir=${TMPDIR:-/tmp}
mkdir -p $backup_dir
echo "Using tmp directory '$backup_dir'"

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
  if [ -d $targetdir ]; then
    echo "Running on '$targetdir'"
    
    #backupdir=${2:-/opt/cloudera/log4shell-backup}
    #mkdir -p "$backupdir"
    echo "Backing up files to '$backup_dir'"
    
    for archivefile in $(find -L $targetdir -name "*.[wnj]ar"); do
      if [ -L  "$archivefile" ]; then
        continue
      fi
	  if grep -q JndiLookup.class $archivefile; then
	  	# Backup file only if backup doesn't already exist
	  	mkdir -p "$backup_dir/$(dirname $archivefile)"
	  	targetbackup="$backup_dir/$archivefile.backup"
	  	if [ ! -f "$targetbackup" ]; then
	  		echo "Backing up to '$targetbackup'"
	  		cp -f "$archivefile" "$targetbackup"
	  	fi
    
	  	# Rip out class
	  	echo "Deleting JndiLookup.class from '$archivefile'"
	  	zip -q -d "$archivefile" \*/JndiLookup.class
	  fi
      
      if unzip -l $archivefile | grep -v 'Archive:' | grep '\.jar$' >/dev/null; then
        doZip=0
      
        rm -r -f $backup_dir/unzip_target
        mkdir $backup_dir/unzip_target
        set +e
        unzip -qq $archivefile -d $backup_dir/unzip_target
        set -e
      
	    for jarfile in $(find -L $backup_dir/unzip_target/ -name "*.jar"); do
	  	if [ -L  "$jarfile" ]; then
	  		continue
	  	fi
	  	if grep -q JndiLookup.class $jarfile; then
	  		# Backup file only if backup doesn't already exist
	  		mkdir -p "$backup_dir/$(dirname $jarfile)"
	  		targetbackup="$backup_dir/$jarfile.backup"
	  		if [ ! -f "$targetbackup" ]; then
	  			echo "Backing up to '$targetbackup'"
	  			cp -f "$jarfile" "$targetbackup"
	  		fi
    
	  		# Rip out class
	  		echo "Deleting JndiLookup.class from '$jarfile' within $archivefile"
	  		zip -q -d "$jarfile" \*/JndiLookup.class
	  		doZip=1
	  	fi
	    done
    
        if [ 1 -eq $doZip ]; then
          tempfile=$(mktemp -u)
          echo "Updating '$archivefile'"
          pushd $backup_dir/unzip_target >/dev/null
          zip -r -q $tempfile .
          popd >/dev/null
    
          chown --reference="$archivefile" "$tempfile"
          chmod --reference="$archivefile" "$tempfile"
          mv -f "$tempfile" "$archivefile"
    
          rm -f $tempfile      
        fi
	  
        rm -r -f $backup_dir/unzip_target
      fi
    done
    
    for tarfile in $(find -L $targetdir -name "*.tar.gz" -o -name "*.tgz"); do
	  if [ -L  "$tarfile" ]; then
	  	continue
	  fi
	  if zgrep -q JndiLookup.class $tarfile; then
	  	$patch_tgz $tarfile $backup_dir
	  fi
    done
  else
    echo "Skipping $targetdir directory as it doesn't exist"
  fi
done

echo "Run successful"

