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

delete_jndi=$BASEDIR/delete_jndi.sh
if [ ! -f "$delete_jndi" ]; then
	echo "Patch script not found: $delete_jndi"
	exit 1
fi

tarfile=$1
if [ ! -f "$tarfile" ]; then
	echo "Tar file '$tarfile' not found"
	exit 1
fi

backupdir=${2:-/opt/cloudera/log4shell-backup}
mkdir -p "$backupdir/$(dirname $tarfile)"
targetbackup="$backupdir/$tarfile.backup"
if [ ! -f "$targetbackup" ]; then
	echo "Backing up to '$targetbackup'"
	cp -f "$tarfile" "$targetbackup"
fi

echo "Patching '$tarfile'"
tempfile=$(mktemp)
tempdir=$(mktemp -d)
tempbackupdir=$(mktemp -d)

tar xf "$tarfile" -C "$tempdir"
$delete_jndi "$tempdir" "$tempbackupdir"

echo "Recompressing"
(cd "$tempdir" && tar czf "$tempfile" --owner=1000 --group=100 .)

# Restore old permissions before replacing original
chown --reference="$tarfile" "$tempfile"
chmod --reference="$tarfile" "$tempfile"

mv "$tempfile" "$tarfile"

rm -f $tempfile
rm -rf $tempdir
rm -rf $tempbackupdir

echo "Patch successful"
