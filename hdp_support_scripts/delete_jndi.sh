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
tmpdir=${TMPDIR:-/tmp}
mkdir -p $tmpdir
echo "Using tmp directory '$tmpdir'"

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
    
    backupdir=${2:-/opt/cloudera/log4shell-backup}
    mkdir -p "$backupdir"
    echo "Backing up files to '$backupdir'"
    
    for jarfile in $(find -L $targetdir -name "*.jar"); do
	  if [ -L  "$jarfile" ]; then
	  	continue
	  fi
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
    
          # Is this jar in jar (uber-jars)?
          if unzip -l $jarfile | grep -v 'Archive:' | grep '\.jar$' >/dev/null; then
            for inner in $(unzip -l $jarfile | grep -v 'Archive:' | grep '\.jar$' | awk '{print $4}'); do
              outfile="$(mktemp)"
              unzip -p $jarfile $inner 2> /dev/null > $outfile
              if unzip -l $outfile | grep JndiLookup.class >/dev/null; then
    
                # Backup file only if backup doesn't already exist
                mkdir -p "$backupdir/$(dirname $jarfile)"
                targetbackup="$backupdir/$jarfile.backup"
                if [ ! -f "$targetbackup" ]; then
                  echo "Backing up to '$targetbackup'"
                  cp -f "$jarfile" "$targetbackup"
                else
                  echo "Backup file exists: ${targetbackup} - skipping backup"
                fi
    
                TMP_DIR=$(mktemp -d)
                pushd $TMP_DIR
                unzip -q $jarfile $inner
                echo "Deleting JndiLookup.class in nested jar $inner of $jarfile"
                zip -q -d $inner \*/JndiLookup.class
                zip -qur $jarfile .
                popd
                rm -rf $TMP_DIR
              fi
	      rm -Rf $outfile
            done
          fi
    done
    
    for warfile in $(find -L $targetdir -name "*.war" -o -name "*.nar"); do
      if [ -L  "$warfile" ]; then
        continue
      fi
      doZip=0
    
      rm -r -f $tmpdir/unzip_target
	  mkdir $tmpdir/unzip_target
	  set +e
	  unzip -qq $warfile -d $tmpdir/unzip_target
	  set -e
	    for jarfile in $(find -L $tmpdir/unzip_target/ -name "*.jar"); do
	  	if [ -L  "$jarfile" ]; then
	  		continue
	  	fi
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
	    pushd $tmpdir/unzip_target
	    zip -r -q $warfile .
	    popd
	  fi
	  
      rm -r -f $tmpdir/unzip_target
    done
    
    for tarfile in $(find -L $targetdir -name "*.tar.gz" -o -name "*.tgz"); do
	  if [ -L  "$tarfile" ]; then
	  	continue
	  fi
	  if zgrep -q JndiLookup.class $tarfile; then
	  	$patch_tgz $tarfile
	  fi
    done
  else
    echo "Skipping $targetdir directory as it doesn't exist"
  fi
done

echo "Run successful"

