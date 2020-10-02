#!/bin/bash
set -euxo pipefail

# this script runs backups, creating full backups when run on the configured
# day of the week and incremental backups when run on other days, tracking the
# backups it has created recently to correctly construct the list of path for
# the INCREMENTAL option.

everyday="11:10" # Must match (including case) the output of `date +%A`.
what="DATABASE bank" # what to backup.
base="gs://backup-cockroach-test/db-backups" # base dir in which to create backups.
recent="recent_backups.txt" # file in which recent backups are recorded.
options="" # e.g. "WITH revision_history"
cmd="cockroach sql --certs-dir=/cockroach-certs --host=my-release-cockroachdb-public" # customize as needed with security/network settings. `-e "stmt$

destination="${base}/$(date +"%Y%m%d-%H%M")"

if [[ "$(date +%R)" == "${everyday}" ]] ; then
    $cmd -e "BACKUP ${what} TO '${destination}' AS OF SYSTEM TIME '-1m'${options};"
    echo ${destination}  > ${recent}
else
  sep=""
  prev=""
  for i in $(cat ${recent}); do prev="${prev}${sep}'${i}'"; sep=", "; done;
  if [ -z "${prev}" ]; then
    echo "Missing prior backups, a full backup is required."
    $cmd -e "BACKUP ${what} TO '${destination}' AS OF SYSTEM TIME '-1m'${options};"
    echo ${destination}  > ${recent}
  else
    destination="${destination}-inc"
    $cmd -e "BACKUP ${what} TO '${destination}' AS OF SYSTEM TIME '-1m' INCREMENTAL FROM ${prev}${options};"
    echo ${destination} >> ${recent}
  fi
fi

