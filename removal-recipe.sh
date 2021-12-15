#!/bin/bash

export TOUCH_DIR=/tmp/jar-fixes

function check_and_delete_from_jar {
  shopt -s globstar
  jarfile=$1
  if grep -q JndiLookup.class $jarfile; then
    # Rip out class
    echo "Deleting JndiLookup.class from '$jarfile'"
    zip -q -d "$jarfile" \*/JndiLookup.class
    if [ ! -z "$2" ]; then
      touch $2
      echo "Narfile touched: $2"
    fi
  fi
}

export -f check_and_delete_from_jar

function delete_from_nar_file {
  shopt -s globstar
  narfile=$1
  echo "Check NAR file: $narfile"
  narfile_md5=$(echo "$narfile" | md5sum | awk '{print $1}')
  narfixed_file=$TOUCH_DIR/$narfile_md5
  unzip_target=$(mktemp -d)
  unzip -qq $narfile -d $unzip_target
  for jarfile in $unzip_target/**/*.jar; do
    check_and_delete_from_jar $jarfile $narfixed_file &
  done

  wait

  if [ -f "$narfixed_file" ]; then
    echo "Updating NAR file: '$narfile'"
    pushd $unzip_target
    zip -q -r $narfile .
    popd
  fi

  rm -r -f $unzip_target
}

export -f delete_from_nar_file

function delete_jndi_from_jar_files {
  if ! command -v zip &> /dev/null; then
    echo "zip not found. zip is required to run this script."
    exit 1
  fi

  targetdir=${1:-/opt/cloudera}
  echo "Check target: '$targetdir'"

  find $targetdir -type f -name '*.jar' -print0 | xargs -0 -n 1 -P 100 -I {} bash -c 'check_and_delete_from_jar "$@"' _ {}
  find $targetdir -type f -name '*.nar' -print0 | xargs -0 -n 1 -P 100 -I {} bash -c 'delete_from_nar_file "$@"' _ {}

  wait

}

export -f delete_jndi_from_jar_files

function delete_jndi_from_targz_file {
  shopt -s globstar
  tarfile=$1
  if [ ! -f "$tarfile" ]; then
    echo "Tar file '$tarfile' not found"
    exit 1
  fi


  echo "Patching '$tarfile'"
  tempfile=$(mktemp)
  tempdir=$(mktemp -d)

  tar xf "$tarfile" -C "$tempdir"

  echo "Temp directory for tar $tarfile: $tempdir"
  delete_jndi_from_jar_files "$tempdir"

  echo "Recompressing $tarfile"
  (cd "$tempdir" && tar czf "$tempfile" --owner=1000 --group=100 .)

  # Restore old permissions before replacing original
  chown --reference="$tarfile" "$tempfile"
  chmod --reference="$tarfile" "$tempfile"

  mv "$tempfile" "$tarfile"

  rm -f $tempfile
  # rm -rf $tempdir

  echo "Completed removing JNDI from tar $tarfile"

}

export -f delete_jndi_from_targz_file

targetdirs=("/opt/cloudera/cm" "/opt/cloudera/parcels")

mkdir -p $TOUCH_DIR

if [ -z "$SKIP_JAR" ]; then
  echo "Removing JNDI from jar files"
  for targetdir in "${targetdirs[@]}"
  do
    delete_jndi_from_jar_files $targetdir &
  done
else
  echo "Skipped patching .jar"
fi

if [ -z "$SKIP_TGZ" ]; then
  echo "Removing JNDI from tar.gz files"
  for targetdir in "${targetdirs[@]}"
  do
    for targzfile in $(find $targetdir -name '*.tar.gz') ; do
      delete_jndi_from_targz_file $targzfile &
    done
  done
else
  echo "Skipped patching .tar.gz"
fi

wait

rm -rf $TOUCH_DIR