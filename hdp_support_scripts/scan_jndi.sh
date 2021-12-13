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

if ! command -v zipgrep &> /dev/null; then
	echo "zipgrep not found. zipgrep is required to run this script."
	exit 1
fi

if ! command -v zgrep &> /dev/null; then
	echo "zgrep not found. zgrep is required to run this script."
	exit 1
fi

for targetdir in /usr/hdp/current /usr/lib /var/lib
do
  echo "Running on '$targetdir'"

  pattern=JndiLookup.class

  shopt -s globstar

  for jarfile in $targetdir/**/*.{jar,tar}; do
	if grep -q $pattern $jarfile; then
		# Vulnerable class/es found
		echo "Vulnerable class: JndiLookup.class found in '$jarfile'"
	fi
  done

  for warfile in $targetdir/**/*.war; do
        rm -r -f /tmp/unzip_target
	mkdir /tmp/unzip_target
	set +e
        unzip -qq $warfile -d /tmp/unzip_target
        set -e
	if grep -r -q $pattern /tmp/unzip_target; then
		# Vulnerable class/es found
		echo "Vulnerable class: JndiLookup.class found in '$warfile'"
	fi
        rm -r -f /tmp/unzip_target
  done

  for tarfile in $targetdir/**/*.{tar.gz,tgz}; do
	if zgrep -q $pattern $tarfile; then
		# Vulnerable class/es found
		echo "Vulnerable class: JndiLookup.class found in '$tarfile'"
	fi
  done
done

echo "Scan complete"
