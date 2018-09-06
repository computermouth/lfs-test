#!/bin/bash

. ~/scripts/comm/dbFuncs.sh

declare -a SlaveErrMsg

REPL_IO_ERROR=1
REPL_SQL_ERROR=2
REPL_DELAY_ERROR=3
REPL_BEHINDMASTER_ERROR=4
SlaveErrMsg=("I/O Thread Stopped" "SQL Thread Stopped" "Slave is 1800 or more seconds behind master" "invalid second_behind_master")
REPL_OK=0

OK=1
FAILED=0

SlaveState=""
SlaveError=""

MYSQLCMD=`which mysql`

#Run a command on a remote host with SSH
s_runRemote()
{
  sshhost=$1
  sshuser=$2
  sshcmd=$3
  remotecmd=$4
  

  echo "running :  ${sshcmd} ${sshuser}@${sshhost} \"${remotecmd}\""
  SlaveState=""
  SlaveState=`${sshcmd} ${sshuser}@${sshhost} "${remotecmd}"`
  ret=$?
  echo "in s_runRemote, status is ${SlaveState}, return ${ret}"
  return $ret;
}

#read slave status with mysql -h option
s_SlaveRunningStatus()
{
        slavehost=$1
        status=1

        #Slave SQL thread status
        SQL=`${MYSQLCMD} -u ${MYSQL_SVR_USER} -p${MYSQL_SVR_PASSWORD} -h ${slavehost} -e "show slave status \G" |grep -i "Slave_SQL_Running:"|awk '{print $2}'`
        echo "mysql slave stauts checking returns  ${SQL}"
        if [ $? -eq 1 ];then
                echo -e "Can't get slave stauts for ${slavehost}";
                return 1
        fi
        #Slave IO thread status
        IO=`${MYSQLCMD} -u ${MYSQL_SVR_USER} -p${MYSQL_SVR_PASSWORD} -h ${slavehost} -e "show slave status \G" |grep -i "Slave_IO_Running"|awk '{print $2}'`
        if [ $? -eq 1 ];then
                echo -e "Can't get slave stauts for ${slavehost}";
                return 1
        fi
        #Slave Second Behind Master status
        SecBehindMaster=`${MYSQLCMD} -u ${MYSQL_SVR_USER} -p${MYSQL_SVR_PASSWORD} -h ${slavehost} -e "show slave status \G" |grep -i "Seconds_Behind_Master"|awk '{print $2}'`
        if [ $? -eq 1 ];then
                echo -e "Can't get slave stauts for ${slavehost}";
                return 1
        fi

        if [ "$SQL" != "Yes" ]; then
                echo -e "\033[31;1mError!!! SlaveStatus():Slave Server ${slavehost} Stopped! SQL Running = ${SQL}\033[0m"
                status=$REPL_SQL_ERROR
                return $status
        else
                echo "Info:SlaveStatus(): Slave_SQL_Running = Yes"
        fi

        if [ "$IO" != "Yes" ]; then
                echo -e "\033[31;1mError!!! SlaveStatus():Slave Server ${slavehost} Stopped! IO Running = ${IO}\033[0m"
                status=$REPL_IO_ERROR
                return $status
        else
                echo "Info:SlaveStatus(): Slave_IO_Running = Yes"
        fi

        if [ "$SecBehindMaster" != "" ]; then
                X=`echo ${SecBehindMaster} | awk '$0 ~/[^0-9]/ { print "nonumber" }'`
                if [ "$X" != "" ] || [ "$X" = "nonumber" ]; then
                        echo -e "\033[31;1mError!!! SlaveStatus():Slave Server ${slavehost} is in wrong status! Seconds_Behind_Master = ${SecBehindMaster} INVALID\033[0m"
                        status=$REPL_BEHINDMASTER_ERROR
                elif [ "$SecBehindMaster" -ge 1800 ]; then
                        echo -e "\033[31;1mWARNING!!! SlaveStatus(): Slave ${SlaveHost} is $SecBehindMaster seconds behind the master $MasterHost.\033[0m"
                        status=$REPL_DELAY_ERROR
                else
                        echo "Info:SlaveStatus(): Seconds_Behind_Master = $SecBehindMaster"
                        status=$REPL_OK
                fi
        else
                echo -e "\033[31;1mWARNING!!! SlaveStatus(): Slave ${SlaveHost} Second_Behind_Master is null.\033[0m"
                status=1
        fi
        return $status
}

###################################################################################
# This function is doing the same slave status check as s_SlaveRunningStatus, but instead of running mysql -h this function use ssh to run mysql locally. The purpose of this function is to check a remote slave by using ssh when mysql 3306 connection is disabled for security resason. 
# read slave status through SSH since connection of 3306 is not always open between hosts
s_RemoteSlaveRunningStatus()
{
        slavehost=$1
	sshcmd=$2
	sshuser=$3
        
	status=1

        #Slave SQL thread status
        cmdSQL="${MYSQLCMD} -u ${MYSQL_SVR_USER} -p${MYSQL_SVR_PASSWORD}  -e \"show slave status \\G\" |grep -i \"Slave_SQL_Running:\"|awk '{print \$2}'"
	s_runRemote $slavehost $sshuser "${sshcmd}" "${cmdSQL}"  
	if [ $? -ne 0 ];then
		echo -e "Can't get slave stauts for ${slavehost}";
		return 1 
	fi

	SQL=$SlaveState
        echo "Slave stauts is ${SlaveState} "

        #Slave IO thread status
        cmdIO="${MYSQLCMD} -u ${MYSQL_SVR_USER} -p${MYSQL_SVR_PASSWORD}  -e \"show slave status \\G\" |grep -i \"Slave_IO_Running:\"|awk '{print \$2}'"
	s_runRemote $slavehost $sshuser "${sshcmd}" "${cmdIO}"  
	if [ $? -ne 0 ];then
		echo -e "Can't get slave stauts for ${slavehost}";
		return 1 
	fi
	IO=$SlaveState
        echo "Slave stauts is ${SlaveState} "

        #Slave Second Behind Master status
        cmdSecBehindMaster="${MYSQLCMD} -u ${MYSQL_SVR_USER} -p${MYSQL_SVR_PASSWORD}  -e \"show slave status \\G\" |grep -i \"Seconds_Behind_Master:\"|awk '{print \$2}'"
	s_runRemote $slavehost $sshuser "${sshcmd}" "${cmdSecBehindMaster}"  
	if [ $? -ne 0 ];then
		echo -e "Can't get slave stauts for ${slavehost}";
		return 1 
	fi
        echo "Slave stauts is ${SlaveState} "
	SecBehindMaster=$SlaveState

        if [ "$SQL" != "Yes" ]; then
                echo -e "\033[31;1mError!!! SlaveStatus():Slave Server ${slavehost} Stopped! SQL Running = ${SQL}\033[0m"
                status=$REPL_SQL_ERROR
		return $status
        else
                echo "Info:SlaveStatus(): Slave_SQL_Running = Yes"
        fi

        if [ "$IO" != "Yes" ]; then
                echo -e "\033[31;1mError!!! SlaveStatus():Slave Server ${slavehost} Stopped! IO Running = ${IO}\033[0m"
                status=$REPL_IO_ERROR
		return $status
        else
                echo "Info:SlaveStatus(): Slave_IO_Running = Yes"
        fi

        if [ "$SecBehindMaster" != "" ]; then
                X=`echo ${SecBehindMaster} | awk '$0 ~/[^0-9]/ { print "nonumber" }'`
                if [ "$X" != "" ] || [ "$X" = "nonumber" ]; then
                        echo -e "\033[31;1mError!!! SlaveStatus():Slave Server ${slavehost} is in wrong status! Seconds_Behind_Master = ${SecBehindMaster} INVALID\033[0m"
                        status=$REPL_BEHINDMASTER_ERROR
                elif [ "$SecBehindMaster" -ge 1800 ]; then
                        echo -e "\033[31;1mWARNING!!! SlaveStatus(): Slave ${SlaveHost} is $SecBehindMaster seconds behind the master $MasterHost.\033[0m"
                        status=$REPL_DELAY_ERROR
                else
                        echo "Info:SlaveStatus(): Seconds_Behind_Master = $SecBehindMaster"
 			status=$REPL_OK
                fi
        else
		echo -e "\033[31;1mWARNING!!! SlaveStatus(): Slave ${SlaveHost} Second_Behind_Master is null.\033[0m"
                status=1
        fi
        return $status
}

#Read slave last_errno through SSH
s_RemoteSlaveErrorCode()
{
        slavehost=$1
        sshcmd=$2
        sshuser=$3
	errorno=$4

        status=1


        cmdError="${MYSQLCMD} -u ${MYSQL_SVR_USER} -p${MYSQL_SVR_PASSWORD}  -e \"show slave status \\G\" |grep -i \"Last_Errno:\"|awk '{print \$2}'"
        s_runRemote $slavehost $sshuser "${sshcmd}" "${cmdError}"
        if [ $? -ne 0 ];then
                echo -e "Can't get slave stauts for ${slavehost}";
                return 1
        fi
	
        SlaveError=$SlaveState
	return 0
}
