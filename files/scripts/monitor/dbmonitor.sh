#!/bin/bash
#####################################################################
#This script is used to checking MySQL DB replication status. 	    #
# 	from mysql  cron job					    #
#       Usage: dbmonitor mysql dbaopt password			    #  
#	Last update: 4/4/2011				            #
#####################################################################



if [ -f $HOME/mysql.env ]; then
        . $HOME/mysql.env
fi


if [ -f $SCRIPT_PATH/monitor/monitor.conf ]; then
	. $SCRIPT_PATH/monitor/monitor.conf
else
	echo "Can't load the file ${SCRIPT_PATH}/monitor/monitor.conf"
	exit
fi



MYSQL_SVR_PASSWORD=$1

s_alarm()
{
	slaveHost=$1
	errorCode=$2
	s_PrintError "!!!!!!!!!!!!!!!!Slave status is wrong on $slaveHost: ${SlaveErrMsg[${errorCode}-1]}"
	s_PrintError "Subject: MySQL Alarm: Slave status on $slaveHost is wrong.\n\n MySQL error: Please check the slave status of server $slaveHost.(Error:${SlaveErrMsg[${errorCode}-1]})" | /usr/sbin/sendmail -f MySQLDBA_HQ2  mysql_dba@businesswire.com 
}

s_info( )
{
	slaveHost=$1
	errorCode=$2
	errorno=$3
	s_PrintError "!!!!!!!!!!!!!!!!Broken slave on $slaveHost (error: $errorCode) has been fixed"
	s_PrintError "Subject: MySQL Info: Broken Slave ${errorno} on $slaveHost has been fixed.\n\n Original MySQL error: Slave status of server $slaveHost.(Error:${SlaveErrMsg[${errorCode}-1]})" | /usr/sbin/sendmail -f MySQLDBA_HQ2  mysql_dba@businesswire.com 
}

s_fix1590()
{
	slaveHost=$1
	errorCode=$2

        echo "Fixing error 1590...."
        cmdSQL="mysql -u ${MYSQL_SVR_USER} -p${MYSQL_SVR_PASSWORD} -e \"STOP SLAVE; SELECT SLEEP(2); CHANGE MASTER TO MASTER_AUTO_POSITION=1; SELECT SLEEP(2);START SLAVE;\""
	s_runRemote "${slaveHost}" "${SSH_USER}" "${SSH}" "${cmdSQL}"
	if [ $? -ne 0 ]; then
		echo  "Fixing error ${errorCode} failed."
		return ${FAILED}
	else		
		echo "Done"
		echo "Check the slave status again...."
		s_RemoteSlaveRunningStatus ${slavehost} "${SSH}" "${SSH_USER}"
		ret=$?
		if [ $? -eq 0 ]; then
			echo "Fixed"
			return ${OK}
		else
			echo "Still broken, need investigate"
			return ${FAILED}
		fi
	fi
	
}
########################  SLAVE STATUS CHECK ########################
echo `date`
if [ "$MYSQL_SVR_PASSWORD" == "" ]; then
	echo "Usage: dbmonitor.sh mysql dbaopt password"
	exit;
fi  

totalServers=${#slave_servers[@]}
count=`expr $totalServers - 1`
while [ "$count" -ge 0 ]                     # while count is less than the number of slaves 
do
	echo -e "\n\nChecking the slave status on ${slave_servers[${count}]}..."
	#s_SlaveRunningStatus ${slave_servers[${count}]} > /dev/null
	s_RemoteSlaveRunningStatus ${slave_servers[${count}]} "${SSH}" "${SSH_USER}"

	ret=$?
	oldret=$ret
	if [ $ret -eq $REPL_OK ]; then 
		s_PrintInfo "OK!\n"
	else
		fixed=0

		#try to fix if its an known issue
		echo -e "\n\nChecking slave errorno on  ${slave_servers[${count}]} ..."
		s_RemoteSlaveErrorCode  ${slave_servers[${count}]} "${SSH}" "${SSH_USER}"  
		echo " Last_Errno:${SlaveError}."
		case "${SlaveError}" in
		'1590') echo "Error 1590 Msg:The incident LOST_EVENTS occured on the master." 
			s_fix1590 ${slave_servers[${count}]} ${SlaveError} 
			fixed=1
			;;
		*) echo "Can not be fixed"
			fixed=0
			;; 
		esac

	        #check slave status again if it has been fixed	
		if [ $fixed -eq 1 ]; then
			s_RemoteSlaveRunningStatus ${slave_servers[${count}]} "${SSH}" "${SSH_USER}"
			newret=$?
		else
			newret=$oldret
		fi

		if [ $newret -eq $REPL_OK ]; then
			s_info ${slave_servers[${count}]} $oldret ${SlaveError}
		else
			s_alarm ${slave_servers[${count}]} $oldret
		fi
		
	fi
	count=`expr $count - 1`
	sleep 1                                 # sleep for a second using the Unix sleep command
done

echo `date`
