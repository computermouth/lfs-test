#!/bin/bash

#Check command line options
if [ $# -ne 2 ]; then
	echo "Usage: StandbyFrom.sh SC|NY 1|2"
	exit
fi
if [ "$1" != "SC" ]; then
	if [ "$1" != "NY" ];then
		echo "Usage: StandbyFrom.sh SC|NY 1|2"
		exit
	fi
fi

if [ "$2" != "1" ]; then
	if [ "$2" != "2" ];then
		echo "Usage: StandbyFrom.sh SC|NY 1|2"
		exit
	fi
fi

####Load HA related functions
if [ -f inc/MySQL_HA.sh ]; then
     . inc/MySQL_HA.sh 
else
     echo "MySQL_HA.sh does not exist."
     exit
fi

#Load enterprise monitor related functions
if [ -f inc/MySQL_EM.sh ]; then
     . inc/MySQL_EM.sh 
else
     echo "MySQL_EM.sh does not exist."
     exit
fi

#Load MySQL service related functions
if [ -f inc/MySQL_Service.sh ]; then
     . inc/MySQL_Service.sh 
else
     echo "MySQL_Service.sh does not exist."
     exit
fi


#Check if the given host is current primary host
#isServiceup "${MASTERHOST1}" "${SERVICE_NAME}"
#if  [ $? -eq $NO ]; then
#	echo -e "${RED} The master host $1:$2 is not the current host attached to the service ${SERVICE_NAME}, please verify. ( use $nslookup ${SERVICE_NAME} to get the current master host.${NORMAL}"
#	exit 1
#fi

echo "This is MySQL cluster ${CLUSTERNAME} with ${NODE} node(s) at each location"

#READ AND VERIFY MySQL ROOT PASSWORD
read -s -p "Enter MYSQL ${ROOT} password: " mysqlRootPassword
while ! mysql -u ${ROOT} -p$mysqlRootPassword  -e ";" ; do
       read -p "Can't connect, please retry: " mysqlRootPassword
done

PWD=$mysqlRootPassword

#READ AND VERIFY MySQL PASSWORD for user repl
read -s -p "Enter MYSQL password for user repl: " mysqlReplPassword
while ! mysql -u repl -p$mysqlReplPassword  -h ${MASTERHOST1} -e ";" ; do
       read -p "Can't connect to user repl, please retry: " mysqlReplPassword
done
REPLPW=$mysqlReplPassword

if [ "$1" == "$LOC1" ]; then
	_remoteloc=$LOC2
else
	_remoteloc=$LOC1
fi

echo "Starting setup ${_remoteloc} as standby, MySQL on the following hosts will be involved."

if [ $NODE -ne 1 ]; then  #This is two nodes cluster
	echo "Is ${MASTERHOST2}  running as the slave of ${MASTERHOST1} correctly?(y/n)"
	read answer

	if [ "$answer" == "y" ] || [ "$answer" == "Y" ]; then
	        MASTERHOST=${MASTERHOST2}
       		echo "MASTER=$MASTERHOST, SLAVE1=$SLAVEHOST1, SLAVE2=$SLAVEHOST2"
	else
       		MASTERHOST=${MASTERHOST1}
	       echo "MASTER=$MASTERHOST SECONDARY_MASTER=${MASTERHOST2} SLAVE1=$SLAVEHOST1, SLAVE2=$SLAVEHOST2"
	fi
else #This is one node cluster, so far HQ TEST and JCON are one node clusters
	MASTERHOST=${MASTERHOST1}
	echo "MASTER=$MASTERHOST SLAVE=$SLAVEHOST1"
fi 

echo " "
echo "Press any key to continue..."
read anything

echo " "

isGTIDEnabled $MASTERHOST1 "$PWD"
isGTID=$?

if [ $isGTID -eq $YES ];then
	echo "$CLUSTERNAME is GTID enabled. Is this graceful/planed switch over? (Y/N)"
	read answer

	if [ "$answer" == "Y" ] || [ "$answer" == "y" ];then
		GRACEFUL=1
	else	
		GRACEFUL=0
	fi
else
	GRACEFUL=0
fi
echo "  Save MySQL id for enterprise monitor.if its not a graceful switchover"
if [ $GRACEFUL -eq 0 ]; then 
	saveEMId "${MASTERHOST1}" "${PWD}" "${BACKUP_DIR}"
	[ $NODE -ne 1 ] && saveEMId "${MASTERHOST2}" "${PWD}" "${BACKUP_DIR}"
	saveEMId "${SLAVEHOST1}" "${PWD}" "${BACKUP_DIR}"
	[ $NODE -ne 1 ] && saveEMId "${SLAVEHOST2}" "${PWD}" "${BACKUP_DIR}"
else
	echo "Skip for graceful switch over"
fi

echo "Backup master on ${MASTERHOST}..."

if [ $GRACEFUL -eq 0 ]; then
	echo "  Backup master on ${MASTERHOST} (y/n)" 
	if [ $INTERACTIVE -ne 0 ]; then read answer; else answer="Y"; fi
	if [ "$answer" == "y" ] || [ "$answer" == "Y" ]; then
		if [ $GRACEFUL -eq 0 ]; then
			do_backup "${MASTERHOST}" "$PWD"
		fi
	fi
else
	echo "Skip backup for graceful switch over"
fi


if [ "$MASTERHOST" == "$MASTERHOST1" ]; then
	if [ $GRACEFUL -eq 0 ]; then
		if [ $NODE -ne 1 ]; then
			createSlave "${MASTERHOST}" "${PWD}"  "${MASTERHOST2}" "${SLAVEHOST1}" "${SLAVEHOST2}"
		else
			createSlave "${MASTERHOST}" "${PWD}"  "${SLAVEHOST1}" 
		fi
	else
		if [ $NODE -ne 1 ]; then
			setSlaves "${MASTERHOST}" "${PWD}"  "${MASTERHOST2}" "${SLAVEHOST1}" "${SLAVEHOST2}"
		else
			setSlaves "${MASTERHOST}" "${PWD}"  "${SLAVEHOST1}" 
		fi
	fi
      
else
	if [ $GRACEFUL -eq 0 ]; then
		if [ $NODE -ne 1 ]; then
			createSlave "${MASTERHOST}" "${PWD}" "${SLAVEHOST1}" "${SLAVEHOST2}"
		else
			createSlave "${MASTERHOST}" "${PWD}" "${SLAVEHOST1}" 
		fi
	else
		if [ $NODE -ne 1 ]; then
			setSlaves "${MASTERHOST}" "${PWD}"  "${SLAVEHOST1}" "${SLAVEHOST2}"
		else
			setSlaves "${MASTERHOST}" "${PWD}"  "${SLAVEHOST1}" 
		fi
	fi
fi

echo "Reload MySQL ID for mysql monitor...."
if [ $GRACEFUL -eq 0 ]; then
	echo "Reload MySQL ID for mysql monitor and bounce the mysql monitor agent on ${MASTERHOST2} ${SLAVEHOST2} and ${SLAVEHOST1} ? (y/n)?"
	if [ $INTERACTIVE -ne 0 ]; then read answer; else answer="Y"; fi
	if [ "$answer" == "y" ] || [ "$answer" == "Y" ]; then
        	if [ "$MASTERHOST" == "$MASTERHOST1" ] && [ $NODE -eq 2 ]; then
                	restore_EMId "${MASTERHOST2}" "${PWD}" "${BACKUP_DIR}"
	        fi
	
        	# wait SLAVEHOST1 change transferred to the SLAVEHOST2, otherwise, ID of slavehost1 will overwrite the change below
	        sleep 10 
        	restore_EMId "${SLAVEHOST1}" "${PWD}" "${BACKUP_DIR}"
	        sleep 10 
		if [ $NODE -ne 1 ]; then
        		restore_EMId "${SLAVEHOST2}" "${PWD}"  "${BACKUP_DIR}"
		fi
	fi
else
	echo "Skip for graceful switchover"
fi

#Make slave and secondary master read only
echo " Make all slave and the secondary master read only (y/n)"
if [ $INTERACTIVE -ne 0 ]; then read answer; else answer="Y"; fi
if [ "$answer" == "y" ] || [ "$answer" == "Y" ]; then
        cmd="mysql -u${ROOT} -p'${PWD}' -e \"set global read_only=ON;\""
        vcmd="mysql -u${ROOT} -p'${PWD}' -e \"show global variables like 'read_only';\""
        str="ON"
        runcmdonhost $SLAVEHOST1 "${cmd}" "${PWD}"
        if [ $NODE -ne 1 ]; then
 		runcmdonhost "${SLAVEHOST2}" "${cmd}" "${PWD}"
	fi
        if [ $NODE -ne 1 ]; then
		runcmdonhost "${MASTERHOST2}" "${cmd}" "${PWD}"
	fi

        verifyResult $SLAVEHOST1 "${vcmd}" "${str}"
        ret1=$?

	if [ $NODE -ne 1 ]; then
        	verifyResult $SLAVEHOST2 "${vcmd}" "${str}"
        	ret2=$?
        	verifyResult $MASTERHOST2 "${vcmd}" "${str}"
        	ret3=$?
	else
		ret2=0
		ret3=0
	fi

        if [ $ret1 -eq 1 ] || [ $ret2 -eq 1 ] || [ $ret3 -eq 1 ]; then
                echo  -e "${RED}FAILED!${NORMAL}"
                INTERACTIVE=1
                echo -e "${RED}Please run mysql -u${ROOT} -p -h ${SLAVEHOST1} -e \"show global variables like 'read_only';\" to check read only status on ${SLAVEHOST1} or ${SLAVEHOST2} or ${MASTERHOST2}, then press anykey to continue ${NORMAL}"
                read anything
        else
                echo -e "${GREEN}SUCCEED!${NORMAL}"
        fi
fi

echo "Switch over complete" | mailx -s "${CLUSTERNAME}  Switch Over -complete" ${ALERTEMAIL}

echo "Don't forget to clean up the backup image created during the switch over"
echo "Don't forget to enable cron job running on mysql2.nyprod disabled before the switch over"

