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

pattern=JndiLookup.class
pattern_15=ClassArbiter.class
pattern_16="MessagePatternConverter\$LookupMessagePatternConverter.class"

backup_dir=$2

#tmpdir=${TMPDIR:-/tmp}
mkdir -p $backup_dir
echo "Using tmp directory '$backup_dir'"

if ! command -v unzip &> /dev/null; then
	echo "unzip not found. unzip is required to run this script."
	exit 1
fi

if ! command -v zgrep &> /dev/null; then
	echo "zgrep not found. zgrep is required to run this script."
	exit 1
fi

for targetdir in ${1:-/usr/hdp/current /usr/hdf/current /usr/lib /var/lib}
do
  echo "Running on '$targetdir'"

  for jarfile in $(find -L $targetdir -name "*.jar" -o -name "*.tar" -o -name "*.war" -o -name "*.nar"); do
	if [ -L  "$jarfile" ]; then
		continue
	fi
	if grep -q $pattern $jarfile; then
		if grep -q $pattern_15 $jarfile; then
			if grep -q $pattern_16 $jarfile; then
				echo "Fixed **2.15** version of Log4j-core found in '$jarfile'"
			else
				echo "Fixed 2.16 version of Log4j-core found in '$jarfile'"
			fi
		else
			echo "Vulnerable version of Log4j-core found in '$jarfile'"
		fi
	fi
	
    # Is this jar in jar (uber-jars)?
    if unzip -l $jarfile | grep -v 'Archive:' | grep '\.jar$' >/dev/null; then
      rm -r -f $backup_dir/unzip_target
      mkdir $backup_dir/unzip_target
      set +e
      unzip -qq $jarfile -d $backup_dir/unzip_target
      set -e
      
      for f in $(grep -l $pattern $(find $backup_dir/unzip_target -name "*.jar")); do
        if grep -q $pattern_15 $f; then
          if grep -q $pattern_16 $f; then
            echo "Fixed **2.15** version of Log4j-core found in '$f' within '$jarfile'"
          else
            echo "Fixed 2.16 version of Log4j-core found in '$f' within '$jarfile'"
          fi
        else
          echo "Vulnerable version of Log4j-core found in '$f' within '$jarfile'"
        fi
      done
      rm -r -f $backup_dir/unzip_target
    fi
  done

  for tarfile in $(find -L $targetdir -name "*.tar.gz" -o -name "*.tgz"); do
	if [ -L  "$tarfile" ]; then
		continue
	fi

	if zgrep -q $pattern $tarfile; then
		if zgrep -q $pattern_15 $tarfile; then
			if zgrep -q $pattern_16 $jarfile; then
				echo "Fixed **2.15** version of Log4j-core found in '$tarfile'"
			else
				echo "Fixed 2.16 version of Log4j-core found in '$tarfile'"
			fi
		else
			echo "Vulnerable version of Log4j-core found in '$tarfile'"
		fi
	fi
  done
done

echo "Scan complete"
