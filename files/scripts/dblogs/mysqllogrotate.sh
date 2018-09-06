#!/bin/bash

if [ -f $HOME/mysql.env ]; then
	. $HOME/mysql.env
else
	echo "${ALARM}:  Can not find the file ${HOME}/mysql.env"
	exit 1
fi



if [ -f ${SCRIPT_PATH}/dblogs/conf/logrotate.conf ];then
	echo "loading configuration file ${SCRIPT_PATH}/dblogs/conf/logrotate.conf ..."
	. ${SCRIPT_PATH}/dblogs/conf/logrotate.conf
	echo "done!"
else
	echo "${ALARM}:  Can not find the configuration file ${SCRIPT_PATH}/dblogs/conf/logrotate.conf"
	exit 1
fi


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
	${SSH}  ${SSH_USER}@${dbSource} "[ -d ${MYSQL_ARCHIVE_LOG_DIR} ] && echo \"Succeed.\" || echo \"${ALARM}!!Failed!\"" 

	######rename the current slow query log file
	echo "Rename current slow query log file..."
	test $DEBUG && echo "${SSH} ${SSH_USER}@${dbSource} \"mv ${MYSQL_SLOW_LOG_DIR}slow_query.log ${MYSQL_ARCHIVE_LOG_DIR}slow_query.log.${datum}\""
	${SSH}   ${SSH_USER}@${dbSource} "mv ${MYSQL_SLOW_LOG_DIR}slow_query.log ${MYSQL_ARCHIVE_LOG_DIR}slow_query.log.${datum}"
	${SSH}  ${SSH_USER}@${dbSource} "[ -e ${MYSQL_ARCHIVE_LOG_DIR}slow_query.log.${datum} ] && echo \"Succeed.\" || echo \"${ALARM}!!!Failed!\"" 

	######rename the current error log file
	echo "Rename the current error log file..." 
	test $DEBUG && echo "${SSH} -v  ${dbSource} \"mv ${MYSQL_ERROR_LOG_DIR}error_log.err ${MYSQL_ARCHIVE_LOG_DIR}error_log.err.${datum};touch ${MYSQL_ERROR_LOG_DIR}error_log.err \""
	# recreate error log file so mysql server can be re-started
	${SSH}  ${SSH_USER}@${dbSource} "mv ${MYSQL_ERROR_LOG_DIR}error_log.err ${MYSQL_ARCHIVE_LOG_DIR}error_log.err.${datum}; touch ${MYSQL_ERROR_LOG_DIR}error_log.err"
	${SSH}  ${SSH_USER}@${dbSource} "[ -e ${MYSQL_ARCHIVE_LOG_DIR}error_log.err.${datum} ] && echo \"Succeed.\" || echo \"${ALARM}!!!Failed!\"" 

	######mysql flush logs will close and reopen the error, slow query log files.
	echo "MySQL FLUSH ERROR LOGS..."
	test $DEBUG && echo "${SSH} ${SSH_USER}@${dbSource} \"${MYSQLCMD} -u ${MYSQL_USER} -pxxxx  -e \\\"flush local error logs;\\\""
	${SSH} ${SSH_USER}@${dbSource} "${MYSQLCMD} -u ${MYSQL_USER} -p${MYSQL_PASSWORD}  -e \"flush local error logs;\""

	echo "MySQL FLUSH slow query LOGS..."
	test $DEBUG && echo "${SSH} ${SSH_USER}@${dbSource} \"${MYSQLCMD} -u ${MYSQL_USER} -pxxxx  -e \\\"flush local slow logs;\\\""
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
