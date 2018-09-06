#!/bin/bash

if [ -f $HOME/mysql.env ]; then
	. $HOME/mysql.env
fi

MYSQL_SLOW_LOG_DIR="/var/mysql/logs/"
MYSQL_ERROR_LOG_DIR="/var/mysql/logs/"
MYSQL_ARCHIVE_LOG_DIR="/var/mysql/logs/archive/"

SLOW_RETENTION=10 # days
ERROR_RETENTION=90 # days
datum=`date +%Y%m%d-%H%M`
MYSQL_USER="dbaopt"
MYSQL_PASSWORD="Zu0Cr0N!"
SSH_USER="mysql"
SSH_CMD=`which ssh` 
SSH="${SSH_CMD} -i $HOME/.ssh/mysqldba_hq_dsa"


if [ -f $SCRIPT_PATH/performance/queries/logrotate.conf ];then
	echo "loading configuration file $SCRIPT_PATH/performance/queries/logrotate.conf ..."
	. $SCRIPT_PATH/performance/queries/logrotate.conf
	echo "done!"
fi
#Assme all MySQL has same base directory
MYSQLCMD=`which mysql`

DEBUG=1

#All servers the slow and error logs files need to be rotated  
declare -a servers 
dbservers=("hq2mysql1.nyprod.businesswire.com" "hq2mysql2.nyprod.businesswire.com" "hq2mysql1.sctest.businesswire.com"  "hq2mysql2.sctest.businesswire.com" "hq2mysql1.scprod.businesswire.com" "hq2mysql2.scprod.businesswire.com" "hq2mysql1.scint.businesswire.com"  "hq2mysql2.nytest.businesswire.com" "hq2mysql1.nytest.businesswire.com" )
dbs=(`echo ${dbservers[@]}`)

totalservers=${#dbservers[@]}
totalservers=`expr $totalservers - 1`
count=0
while [ "$count" -le "$totalservers" ]
do
	dbSource=${dbs[${count}]}
	echo "${dbSource}"

	######Create archive directory if not exists
	echo "Create directory ${MYSQL_ARCHIVE_LOG_DIR} on ${dbSource} if it doesn't exist..." 
	test $DEBUG && echo "${SSH} ${SSH_USER}@${dbSource} \"[ -d ${MYSQL_ARCHIVE_LOG_DIR} ] || mkdir ${MYSQL_ARCHIVE_LOG_DIR} && chmod 700 ${MYSQL_ARCHIVE_LOG_DIR}\"" 
	${SSH}  ${SSH_USER}@${dbSource} "[ -d ${MYSQL_ARCHIVE_LOG_DIR} ] || mkdir ${MYSQL_ARCHIVE_LOG_DIR} && chmod 700 ${MYSQL_ARCHIVE_LOG_DIR}" 
	${SSH}  ${SSH_USER}@${dbSource} "[ -d ${MYSQL_ARCHIVE_LOG_DIR} ] && echo \"Succeed.\" || echo \"ALARM!!Failed!\"" 

	######rename the current slow query log file
	echo "Rename current slow query log file..."
	test $DEBUG && echo "${SSH} ${SSH_USER}@${dbSource} \"mv ${MYSQL_SLOW_LOG_DIR}slow_query.log ${MYSQL_ARCHIVE_LOG_DIR}slow_query.log.${datum}\""
	${SSH}   ${SSH_USER}@${dbSource} "mv ${MYSQL_SLOW_LOG_DIR}slow_query.log ${MYSQL_ARCHIVE_LOG_DIR}slow_query.log.${datum}"
	${SSH}  ${SSH_USER}@${dbSource} "[ -e ${MYSQL_ARCHIVE_LOG_DIR}slow_query.log.${datum} ] && echo \"Succeed.\" || echo \"ALARM!!!Failed!\"" 

	######rename the current error log file
	echo "Rename the current error log file..." 
	test $DEBUG && echo "${SSH} -v  ${dbSource} \"mv ${MYSQL_ERROR_LOG_DIR}error_log.err ${MYSQL_ARCHIVE_LOG_DIR}error_log.err.${datum}\""
	${SSH}  ${SSH_USER}@${dbSource} "mv ${MYSQL_ERROR_LOG_DIR}error_log.err ${MYSQL_ARCHIVE_LOG_DIR}error_log.err.${datum}"
	${SSH}  ${SSH_USER}@${dbSource} "[ -e ${MYSQL_ARCHIVE_LOG_DIR}error_log.err.${datum} ] && echo \"Succeed.\" || echo \"ALARM!!!Failed!\"" 

	######mysql flush logs will close and reopen the error, slow query log files.
	echo "MySQL FLUSH ERROR LOGS..."
	test $DEBUG && echo "${SSH} ${SSH_USER}@${dbSource} \"${MYSQLCMD} -u ${MYSQL_USER} -p${MYSQL_PASSWORD}  -e \\\"flush local error logs;\\\""
	${SSH} ${SSH_USER}@${dbSource} "${MYSQLCMD} -u ${MYSQL_USER} -p${MYSQL_PASSWORD}  -e \"flush local error logs;\""

	echo "MySQL FLUSH slow query LOGS..."
	test $DEBUG && echo "${SSH} ${SSH_USER}@${dbSource} \"${MYSQLCMD} -u ${MYSQL_USER} -p${MYSQL_PASSWORD}  -e \\\"flush local slow logs;\\\""
	${SSH} ${SSH_USER}@${dbSource} "${MYSQLCMD} -u ${MYSQL_USER} -p${MYSQL_PASSWORD}  -e \"flush local slow logs;\""

	#####purge the old logs files
	  #slow query log
	echo "${SSH} ${SSH_USER}@${dbSource} \"find ${MYSQL_ARCHIVE_LOG_DIR}slow_query.log.20* -type f -mtime +${SLOW_RETENTION} -exec rm {} \\\\;\""
	${SSH} ${SSH_USER}@${dbSource} "find ${MYSQL_ARCHIVE_LOG_DIR}slow_query.log.20* -type f -mtime +${ERROR_RETENTION} -exec rm {} \\;"
	 #error log
	echo "${SSH} ${SSH_USER}@${dbSource} \"find ${MYSQL_ARCHIVE_LOG_DIR}error_log.err.20* -type f -mtime +${SLOW_RETENTION} -exec rm {} \\\\;\""
	${SSH} ${SSH_USER}@${dbSource} "find ${MYSQL_ARCHIVE_LOG_DIR}error_log.err.20* -type f -mtime +${ERROR_RETENTION} -exec rm {} \\;"

        count=`expr ${count} + 1`
done

echo `date`
echo "Complete!"
