#!/bin/bash

#####################################################################
#This script is used to checking MySQL DB replication status. 	    #
# 	from mysql  cron job					    #
#       Usage: dbmonitor mysql dbaopt password			    #  
#	Last update: 4/4/2011				            #
#####################################################################


MYSQL_SVR_PASSWORD=$1
prog=$0


echo `date`
if [ "$MYSQL_SVR_PASSWORD" == "" ]; then
        echo "Usage: processmonitor.sh dbaopt_password"
        exit;
fi

if [ -f $HOME/mysql.env ]; then
        . $HOME/mysql.env
fi


if [ -f $SCRIPT_PATH/monitor/processmonitor.conf ]; then
	. $SCRIPT_PATH/monitor/processmonitor.conf
else
	echo "Can't load the file ${SCRIPT_PATH}/monitor/processmonitor.conf"
	exit
fi

s_alarm()
{
	errormsg=$1
	detail=$2
	s_PrintError "!!!!!!!!!!!!!!!!$2!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
	s_PrintError "Subject: MySQL Process Monitor Alert:  \n\n error: ${errormsg} \n ${detail}" | /usr/sbin/sendmail -f MySQLDBA_HQ2  mysql_dba@businesswire.com 
}


#check if the program is already running before starting another conection to eliminate multiple connections to the DB
echo "Check if the prog is running already"
if [ "$(ps -ef | grep ${prog} | grep -v grep | wc -l)" -gt 3 ]; then
	echo " This program is already running."  
        host=`hostname -f`
	s_alarm "Process Monitor process is running too long"  "Please check the process $0 status on  $host"
	exit
fi






totalprocess=0
waitinglock=0


s_check_processstatus ()
{
    sshhost=$1
    sshcmd=$2
    sshuser=$3

    remotecmd="mysql -u ${MYSQL_SVR_USER} -p${MYSQL_SVR_PASSWORD} -e \"SELECT ID,USER,HOST,DB,COMMAND,STATE,TIME,INFO FROM information_schema.processlist WHERE state is not null and command not in (\\\"Sleep\\\",\\\"Binlog Dump GTID\\\") AND TIME >= ${TIME};\" | grep \"^[0-9]\" "
    echo $remotecmd
    
    process=`${sshcmd} ${sshuser}@${sshhost} "${remotecmd}"`
    ret=$?   # security warning will cause return status = 1
    if [ "$process" == "" ] && { [ $ret -eq 0 ] || [ $ret -eq 1 ]; }; then
	echo "No process returned"
    else
	errormsg="${sshhost}:Found running MySQL process(es) taking more than ${TIME} seconds."
	#collect status
        scmd="mysql -u ${MYSQL_SVR_USER} -p${MYSQL_SVR_PASSWORD} -e \"SELECT 'INNODB_TRX';SELECT * FROM information_schema.innodb_trx; SELECT 'INNODB_LOCKS'; SELECT 'INNODB_LOCK_WAITS'; SELECT * FROM information_schema.innodb_locks; select * from information_schema.innodb_lock_waits;show engine innodb status\\G;\""
	echo " Collecting DB status :   ${scmd}"
        status=`${sshcmd} ${sshuser}@${sshhost} "${scmd}"`
	s_alarm "$errormsg" "$process $status"

    fi

    echo " "
    echo " "
    echo " "
}



########################  PROCESS STATUS CHECK ########################

totalServers=${#servers[@]}
count=`expr $totalServers - 1`
while [ "$count" -ge 0 ]                     # while count is less than the number of slaves 
do
	echo -e "\n\nChecking the process status on ${servers[${count}]}..."
	s_check_processstatus ${servers[${count}]} "${SSH}" "${SSH_USER}"

	count=`expr $count - 1`
	sleep 1
done

echo `date`
