# cloudera-scripts-for-log4j

This repo contains scripts and helper tools to mitigate the critical
log4j vulnerability [CVE-2021-44228](https://nvd.nist.gov/vuln/detail/CVE-2021-44228)
for Cloudera products affecting all versions of log4j between 2.0 and 2.14.1.

Please read the technical service bulletin found [here](https://my.cloudera.com/knowledge/TSB-2021-545-Critical-vulnerability-in-log4j2-CVE-2021-44228?id=332019)
for an analysis of which products have been affected, and find the
mitigations in the actions required section for the TSB.

If you are using “CDH, HDP, and HDF” or “CDP Private Cloud”, refer to [Resolution for TSB-545 - Private Cloud Version](https://my.cloudera.com/knowledge/Title-Resolution-for-TSB-545---Critical-vulnerability-in?id=332012) 

If you are using “CDP Public Cloud”, refer to [Resolution for TSB-545 - Public Cloud Version](https://my.cloudera.com/knowledge/Resolution-for-TSB-545---Critical-vulnerability-in-log4j2-CVE?id=332005)

## Running the script
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
```
    Usage: run_log4j_patcher.sh (subcommand) [options]
    Subcommands:
        help              Prints this message
        cdh               Scan a CDH cluster node
        cdp               Scan a CDP cluster node
        hdp               Scan a HDP cluster node
        hdf               Scan a HDF cluster node

    Options (cdh and cdp subcommands only):
        -t <targetdir>    Override target directory (default: distro-specific)
        -b <backupdir>    Override backup directory (default: /opt/cloudera/log4shell-backup)

    Environment Variables:
        SKIP_JAR          If non-empty, skips scanning and patching .jar files
        SKIP_TGZ          If non-empty, skips scanning and patching .tar.gz files (cdh and cdp only)
        SKIP_HDFS         If non-empty, skips scanning and patching .tar.gz files in HDFS
        RUN_SCAN          If non-empty, runs a final scan for missed vulnerable files. This can take several hours.
```
HDP Notes : Currently the HDP removal scrips works on folder `/user/`  on HDFS. Please modify/extent in The `hdp_log4j_jndi_removal.sh` around `line 19`.  
