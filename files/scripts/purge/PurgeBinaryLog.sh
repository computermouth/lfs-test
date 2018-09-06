#!/bin/bash
. ~/scripts/comm/monitor.sh
. ~/scripts/comm/output.sh

trap 'increment' 2

increment()
{
  echo "Caught SIGINT ..."
  echo "Okay, PurgeBinaryLog.sh will quit ..."
  exit 1
}

if [ -f $HOME/mysql.env ];then
    . $HOME/mysql.env
fi

RETENTION=5 #days
#User privilege for dbaopt: super,reload
#show slave stauts needs: replication client or super
#purge binary log needs: super

RUN_INTERACTIVE=0
DEBUG=1
MYSQLCMD=`which mysql`
SSH_KEY="/home/mysql/.ssh/mysqldba_hq_dsa"
SSH=`which ssh`
SSH_CMD="${SSH} -i ${SSH_KEY}"

MYSQL_SVR_USER=dbaopt


s_Exit ()
{
	echo "Purging for ${MasterHost} is terminated."
}

CurBinLogFile=""
s_getRemoteBinaryFile()
{
       SlaveHost=$1
       sshcmd=$2
       sshuser=$3
       remotecmd=$4
       # echo "call s_runRemote to run :  ${sshcmd} ${sshuser}@${SlaveHost} \"${remotecmd}\""
 
       CurBinLogFile=`s_runRemote ${SlaveHost} "${sshuser}" "${sshcmd}" "${remotecmd}"`
}
echo -e "\n\n"
echo "######################################################################"
echo "	PurgeBinaryLog.sh: Purge binary log files on $2"		
echo "######################################################################"
echo `date`
if [ $# -lt 2 ];then
	#echo "!!!!!!ERROR:Main(): Please provide master host and its slave host name(s) and run the script again."
	#s_Exit
	#exit 1
#elif [ $# -lt 3 ] && [ $2 != "hq2mysql1.sfdev.businesswire.com" ] &&  [ $2 != "aegir1.sftest" ] && [ $2 != "mysql1.sftest" ] && [  $2 != "mysql1.nyprod" ] && [ $2 != "aegir1.nyprod" ]; then
	s_PrintWarning "!!!WARNING:Main(): You are going to purge the binary logs on $2 without checking the slave status, it could break the replication. Continue(y/n)?"
	if [ "$RUN_INTERACTIVE" -ne 1 ]; then
		answer="N"
	else
		read answer
	fi
	if [ "$answer" != "y" ] && [ "$answer" != "Y" ];then
		s_Exit
		exit 1 
	fi
fi

MYSQL_SVR_PASSWORD=$1
shift
MasterHost=$1
shift

echo -e "\n\n###Info:Main(): Checking all slave status before purging the binary logs on $MasterHost...."
while [ $# -gt 0 ]
do
	SlaveHost=$1
	shift

	echo -e "\nInfo: Main(): Checking slave host $SlaveHost status..."
	s_RemoteSlaveRunningStatus ${SlaveHost} "${SSH_CMD}" "mysql"

	status=$?
	if [ $status -ne 0  ] ;then
		s_PrintError "!!!!!!!!!!Error:Main(): Can't verify Slave $SlaveHost is running properly, stop purging binary log on the Master $MasterHost."
		if [ "$RUN_INTERACTIVE" -ne 1 ]; then
			answer="N"
		else
			echo -e "\nContinue(y/n)?"
			read answer
		fi 

		if [ "$answer" != "Y" ] && [ "$answer" != "y" ]; then
			s_Exit
			exit 1 
		fi
	else
		CurBinLogFilecmd="${MYSQLCMD} -u ${MYSQL_SVR_USER} -p${MYSQL_SVR_PASSWORD} -h ${SlaveHost} -e \"show slave status \\G\" |grep -i \"Relay_Master_log_file\"|awk '{print \$2}'"
		#s_RemoteSlaveRunningStatus ${SlaveHost} "${SSH_CMD}" "mysql"  "${CurBinLogFilecmd}"
  		s_runRemote $slavehost $sshuser "${sshcmd}" "${CurBinLogFilecmd}"
        	if [ $? -ne 0 ];then
			s_PrintError "!!!!!!Error:Main():There is a problem to get current relay log list from master ${MasterHost}\n"
			s_Exit 
			exit 1
        	fi

	        CurBinLogFile=$SlaveState
		echo -n "Info:Main(): Relay_Master_Log_File: $CurBinLogFile"

		filedate=`${SSH_CMD} $MasterHost "ls -l /var/mysql/data/${CurBinLogFile} | awk '{print \\$6, \\$7}'"`
		echo " ( created on $filedate )"
		echo "${SSH_CMD} $SlaveHost \"find /var/mysql/data/${CurBinLogFile} -mtime +${RETENTION}\""
		older=`${SSH_CMD} $MasterHost "find /var/mysql/data/${CurBinLogFile} -mtime +${RETENTION}"`
		if [ "$older" = "" ]; then
			s_PrintInfo "From ${SlaveHost}:Its OK for the master to purge the logs which are more than ${RETENTION} days old."
		else
			s_PrintInfo "From ${SlaveHost}!!!WARNING:Main(): This slave is still processing the binary log ${RETENTION} days older, purging on the master will break the replication. Continue? (y/n)" 
			if [ "$RUN_INTERACTIVE" -ne 1 ]; then
				answer="N"
			else
				read answer
			fi
			if [ "$answer" != "Y" ] && [ "$answer" != "y" ]; then
				s_Exit 
				exit 1
			fi

		fi
	fi
done

echo -e "\n\n###Info:Main(): Purge date:"`date`
echo ""
echo "Info:Main(): Before purge, master $MasterHost binary logs..."
getBinLogcmd="${MYSQLCMD} -u ${MYSQL_SVR_USER} -p${MYSQL_SVR_PASSWORD}  -e \"SHOW BINARY LOGS;\""
echo ${SSH_CMD}
s_runRemote ${MasterHost} "mysql" "${SSH_CMD}" "${getBinLogcmd}"
if [ $? -eq 1 ];then
	s_PrintError "!!!!!!Error:Main():There is a problem to get binary log list from master ${MasterHost}\n"
	s_Exit 
        exit 1	
fi
${SSH_CMD} mysql@${MasterHost} "ls -l /var/mysql/data/mysql-bin.*"
if [ $? -eq 1 ];then
	s_PrintError  "!!!!!!!Error:Main(): There is a problem to get binary log file list from master ${MasterHost}"
	s_Exit 
	exit 1
fi

echo -e "\\n###INFO:Main(): Start purging the binary logs on $MasterHost? (y/n)"
if [ "$RUN_INTERACTIVE" -ne 1 ]; then
	answer="Y"
else
	read answer
fi

if [ "$answer" = "y" ] || [ "$answer" = "Y" ];then

	echo "ssh cmd is "
	echo "${SSH_CMD}"
	echo "Purge binary log on $MasterHost..."
	purgecmd="${MYSQLCMD} -u ${MYSQL_SVR_USER} -p${MYSQL_SVR_PASSWORD} -e \"PURGE BINARY LOGS BEFORE DATE_SUB(NOW(), INTERVAL ${RETENTION} DAY);\""
	echo "run on ${MasterHost} : ${purgecmd}"
	s_runRemote ${MasterHost} "mysql" "${SSH_CMD}"  "${purgecmd}"
	echo -e "\nInfo:Main(): After purge, master $MasterHost binary logs..."
	getBinLogcmd="${MYSQLCMD} -u ${MYSQL_SVR_USER} -p${MYSQL_SVR_PASSWORD} -e \"SHOW BINARY LOGS;\""
	s_runRemote ${MasterHost} "mysql" "${SSH_CMD}"  "${getBinLogcmd}"
	${SSH_CMD}  mysql@${MasterHost} "ls -l /var/mysql/data/mysql-bin.*"
else
	echo "No binary log file on $MasterHost is purged."
fi

echo -e "\n\n###INFO:Main(): Purging for ${MasterHost} is complete!\n\n"
