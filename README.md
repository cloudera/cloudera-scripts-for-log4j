# cloudera-scripts-for-log4j
This repo contains Cloudera Scripts for log4j

WARNING: This script should only be run under the guidance of Cloudera Support.

run_log4j_patcher.sh scans a directory for jar files and removes
JndiLookup.class from the ones it finds. Do not run any
other scripts in this directory--they will be called by
run_log4j_patcher.sh automatically.

1. Run the script as root on ALL nodes of your cluster.
   * Script will take 1 mandatory argument (cdh|cdp|hdp)
   * (For CDH and CDP only) The script takes 2 optional arguments: a base
     directory to scan in, and a backup directory. The default for both are
     /opt/cloudera and /opt/cloudera/log4shell-backup, respectively. These
     defaults work for CM/CDH 6 and CDP 7. A different set of directories will
     be used for HDP.
2. Ensure that the last line of the script output indicates ‘Finished’ to
   verify that the job has completed successfully. The script will fail if a
   command exits unsuccessfully.
3. Restart Cloudera Manager Server or Ambari, all clusters, and all running
   jobs and queries.

Usage: run_log4j_patcher.sh (subcommand) [options]
    Subcommands:
        help              Prints this message
        cdh               Scan a CDH cluster node
        cdp               Scan a CDP cluster node
        hdp               Scan a HDP cluster node

    Options (cdh and cdp subcommands only):
        -t <targetdir>    Override target directory (default: distro-specific)
        -b <backupdir>    Override backup directory (default: /opt/cloudera/log4shell-backup)

    Environment Variables (cdh and cdp subcommands only):
        SKIP_JAR          If non-empty, skips scanning and patching .jar files
        SKIP_TGZ          If non-empty, skips scanning and patching .tar.gz files
        SKIP_HDFS         If non-empty, skips scanning and patching .tar.gz files in HDFS
        RUN_SCAN          If non-empty, runs a final scan for missed vulnerable files. This can take several hours.

HDP Notes : Currently the HDP removal scrips works on folder `/user/`  on HDFS. Please modify/extent in The `hdp_log4j_jndi_removal.sh` around `line 19`.  