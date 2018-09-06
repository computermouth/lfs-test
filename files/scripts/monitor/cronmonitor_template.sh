#!/bin/bash
#This script is to list all the log files generated within last 10 hours by cron job


m=$1  #within how many minutes the log should be counted

echo -e "\n"
echo `hostname -f`
echo -e "\n"
. ~/mysql.env
find $SCRIPT_PATH/logs/.  -name '*.log' -mmin -$m -exec ls -ltr {} \;
totaln=`find ${SCRIPT_PATH}/logs  -name '*.log' -mmin -$m -exec ls -ltr {} \; | wc -l`

let h="${m}/60"
echo -e  "\n\nTotal ${totaln} cron job logs were generated with last $h hours"
echo  "		Total daily jobs: 6 (backup, purge, log rotate, aegir users,GTI monitor,cron monitor)"
echo  "		Total weeks jobs: 4 ( replication checksum on prod and test, 2 for each)" 
echo  "		Total month jobs: 1 ( slow query log the first thursday each month)" 

