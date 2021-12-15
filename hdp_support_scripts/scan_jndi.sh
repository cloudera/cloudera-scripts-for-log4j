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
shopt -s dotglob
shopt -s nullglob 

pattern=JndiLookup.class
good_pattern=ClassArbiter.class

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

  for jarfile in $targetdir/**/*.{jar,tar}; do
	if grep -q $pattern $jarfile; then
		if grep -q $good_pattern $jarfile; then
			echo "Fixed version of Log4j-core found in '$jarfile'"
		else
			echo "Vulnerable version of Log4j-core found in '$jarfile'"
		fi
	fi
  done

  for warfile in $targetdir/**/*.{war,nar}; do
        rm -r -f /tmp/unzip_target
	mkdir /tmp/unzip_target
	set +e
	unzip -qq $warfile -d /tmp/unzip_target
	set -e
	
    found=0  # not found
    for f in $(grep -r -l $pattern /tmp/unzip_target); do
      found=1  # found vulnerable class
      if grep -q $good_pattern $f; then
        found=2  # found fixed class
      fi
    done
    if [ $found -eq 2 ]; then
      echo "Fixed version of Log4j-core found in '$warfile'"
    elif [ $found -eq 1 ]; then
      echo "Vulnerable version of Log4j-core found in '$warfile'"
    fi
    rm -r -f /tmp/unzip_target
  done

  for tarfile in $targetdir/**/*.{tar.gz,tgz}; do
	if zgrep -q $pattern $tarfile; then
		if zgrep -q $good_pattern $tarfile; then
			echo "Fixed version of Log4j-core found in '$tarfile'"
		else
			echo "Vulnerable version of Log4j-core found in '$tarfile'"
		fi
	fi
  done
done

echo "Scan complete"
