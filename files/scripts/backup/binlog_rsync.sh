#!/bin/bash

#########################################################################################
#       Name: binlog_rsync.sh                                                           #
#             rsync binary log files to NYProdi7-z1 local disk		                #
#       Usage: binlog_rsync.sh		                                                #
#               The servers are given in the variable servers			        #
#               This script is running as a cron job on nyprodi7-z1 during midnight     #
#       Output:  nyprodi7-z1:/var/mysql/backup/binlog/xxxx/mysql-bin*                   #
#                       xxx: server name                                                #
#       Author:  Min Chen                                                               #
#       Last update: 11/30/2010                                                         #
#########################################################################################

#Configuration
RETENTION=10
servers=("sfprodi7-z1" "mysql1.sfprod.businesswire.com"  "aegir1.sfprod.businesswire.com" "mysql1.sftest.businesswire.com")

RSYNC=/usr/local/bin/rsync
BINLOG_DIR="/var/mysql/data/"
BACKUP_DIR_ROOT="/var/mysql/backup/binlog/"
#end Configuration

declare -a dbs
declare -a servers

#########################################################################
#   Rsync binary log files from the data directory to its dest location #
#########################################################################

s_binlogRsync()
{
	dbSource=$1

	echo `date`
	echo "rsync bin logs from $dbSource..."
	echo "${RSYNC} -avz --delete --sockopts=SO_SNDBUF=150000,SO_RCVBUF=150000 --rsync-path=/usr/local/bin/rsync ${dbSource}:${BINLOG_DIR}mysql-bin.* ${BACKUP_DIR_ROOT}${dbSource}/"
	$RSYNC -avz --delete --rsync-path=/usr/local/bin/rsync ${dbSource}:${BINLOG_DIR}mysql-bin.* ${BACKUP_DIR_ROOT}${dbSource}/

        echo "find ${BACKUP_DIR_ROOT}${dbSource}/* -type f -mtime +${RETENTION} -exec rm {} \\\
\;\""
        find ${BACKUP_DIR_ROOT}${dbSource}/* -type f -mtime +${RETENTION} -exec rm {} \;
	echo "Done!"
	echo `date`
}

#################################################################
#   Main : rsync binary log		       			#	
#################################################################

echo -e "\n\n\n\n ############MySQL binary rsync is started....##########\n"
echo `date`
dbs=(`echo ${servers[@]}`)
echo ${dbs[@]}

totalServers=${#dbs[@]}
totalServers=`expr $totalServers - 1`
count=0
while [ "$count" -le "$totalServers" ]
do
	dbSource=${dbs[${count}]}
	BACKUP_DIR="${BACKUP_DIR_ROOT}${dbSource}"
	######Create archive directory if not exists
        echo "Create directory ${BACKUP_DIR} on host if it doesn't exist..."
        echo "[ -d ${BACKUP_DIR} ] || mkdir ${BACKUP_DIR} && chmod 700 ${BACKUP_DIR}"
        [ -d ${BACKUP_DIR} ] || mkdir ${BACKUP_DIR} && chmod 700 ${BACKUP_DIR}
        [ -d ${BACKUP_DIR} ] || echo "${BACKUP_DIR} does not existed!"

	s_binlogRsync ${dbs[${count}]}
	count=`expr ${count} + 1`
done
echo `date`
echo -e "\n\n ############MySQL binary log rsync process is complete...##########\n\n"
