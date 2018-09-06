#!/bin/bash

#Check command line options
#if [ $# -ne 1 ]; then
#        echo "Usage: SwitchOver.sh SF|SC"
#        exit
#fi

#if [ "$1" != "SF" ]; then
#        if [ "$1" != "SC" ];then
#                echo "Usage: SwitchOver.sh SF|SC "
#                exit
#        fi
#fi


masterlocation=$1

####Load HA and Service related functions
if [ -f inc/MySQL_HA.sh ]; then
     . inc/MySQL_HA.sh 
else
     echo "MySQL_HA.sh does not exist."
     exit
fi

#Load enterprise monitor related functions
if [ -f inc/MySQL_Service.sh ]; then
     . inc/MySQL_Service.sh 
else
     echo "MySQL_Service.sh does not exist."
     exit
fi

#READ AND VERIFY MySQL ROOT PASSWORD
read -s -p "Enter MYSQL root password: " mysqlRootPassword
while ! mysql -u ${ROOT} -p$mysqlRootPassword  -e ";" ; do
       read -p "Can't connect, please retry: " mysqlRootPassword
done

PWD=$mysqlRootPassword


echo "Switching over to  $1."
echo "MASTER1=${masterhost1}, MASTER2=${masterhost2} SLAVE1=${slavehost1}, SLAVE2=${slavehost2}"
echo "Service Name is ${SERVICE_NAME}"


INTERACTIVE=1

#If the cluster use alias as service name, disable service. So far only jcon doesn't have alias
if [ "$SERVICE_NAME" != "" ];then
	echo "Disable MySQL server ${SERVICE_NAME} on all MySQL hosts (y/n)?"
	if [ $INTERACTIVE -ne 0 ]; then read answer; else answer="Y"; fi
	if [ "$answer" == "y" ] || [ "$answer" == "Y" ]; then
		disableService allhosts[@] "${SERVICE_NAME}"
		ret=$?
		if [ $ret -eq $FAILED ];then
			INTERACTIVE=1
			echo -e "${RED}Please run nslookup ${SERVICE_NAME} to check service status.i then press anykey to continue ${NORMAL}"
			read anything
		fi
	fi
fi

#Stop slave on new master location 

echo "  Stop slave on ${masterhost1} (y/n)"
if [ $INTERACTIVE -ne 0 ]; then read answer; else answer="Y"; fi
if [ "$answer" == "y" ] || [ "$answer" == "Y" ]; then
	stopSlave "${masterhost1}" "${PWD}"
	if [ $? -eq 0 ];then
		echo -e "${GREEN}SUCCEED!${NORMAL}"
	else
		echo -e  "${RED}FAILED!${NORMAL}"
		INTERACTIVE=1
		echo -e "${RED}Please run mysql -u${ROOT} -p -h ${masterhost1} -e "show slave status\G;" to check slave status on ${masterhost1}, then press anykey to continue ${NORMAL}"
		read anything
	fi
fi



#Make slave and secondary master read only
echo " Make ${slavelocation} read only (y/n)"
if [ $INTERACTIVE -ne 0 ]; then read answer; else answer="Y"; fi
if [ "$answer" == "y" ] || [ "$answer" == "Y" ]; then
	cmd="mysql -u${ROOT} -p'${PWD}' -e \"set global read_only=ON;\""
	vcmd="mysql -u${ROOT} -p'${PWD}' -e \"show global variables like 'read_only';\""
	str="ON"
	runcmdonhost $slavehost1 "${cmd}" "${PWD}"
	[ $NODE -ne 1 ] && runcmdonhost $slavehost2 "${cmd}" "${PWD}" && runcmdonhost $masterhost2 "${cmd}" "${PWD}"
	verifyResult $slavehost1 "${vcmd}" "${str}"
	ret1=$?
	if [ $NODE -ne 1 ];then
		verifyResult $slavehost2 "${vcmd}" "${str}"
		ret2=$?
		verifyResult $masterhost2 "${vcmd}" "${str}"
		ret3=$?
	else
		ret2=0
		ret3=0
	fi

        if [ $ret1 -eq 1 ] || [ $ret2 -eq 1 ] || [ $ret3 -eq 1 ] ;then
                echo  -e "${RED}FAILED!${NORMAL}"
                INTERACTIVE=1
		echo -e "${RED}Please run mysql -u${ROOT} -p -h ${slavehost1} -e \"show global variables like 'read_only';\" to check read only status on ${slavehost1} or ${slavehost2} or ${masterhost2}, then press anykey to continue ${NORMAL}"
		read anything
        else
                echo -e "${GREEN}SUCCEED!${NORMAL}"
        fi
fi



#Make master location writable
echo " Make $masterlocation writeable  (y/n)"
if [ $INTERACTIVE -ne 0 ]; then read answer; else answer="Y"; fi
if [ "$answer" == "y" ] || [ "$answer" == "Y" ]; then
        cmd="mysql -u${ROOT} -p'${PWD}' -e \"set global read_only=OFF;\""
        runcmdonhost ${masterhost1} "$cmd" "${PWD}"
        vcmd="mysql -u${ROOT} -p'${PWD}' -e \"show global variables like 'read_only';\""
        str="OFF"
        runcmdonhost "${masterhost1}" "${cmd}" "${PWD}"
        verifyResult "${masterhost1}" "${vcmd}" "${str}"
        ret1=$?
        if [ $ret1 -eq 1 ]; then
                echo  -e "${RED}FAILED!${NORMAL}"
                INTERACTIVE=1
                echo -e "${RED}Please run mysql -u${ROOT} -p -h ${masterhost1} -e \"show global variables like 'read_only';\" to check read only status on ${masterhost1}, then press anykey to continue ${NORMAL}"
                read anything
        else
                echo -e "${GREEN}SUCCEED!${NORMAL}"
        fi
fi

#If the cluster use alias as service name, disable service. So far only jcon doesn't have alias
if [ "$SERVICE_NAME" != "" ];then
	#enable service on the primary host@master location
	echo " Enable service on $masterhost1  (y/n)"
	if [ $INTERACTIVE -ne 0 ]; then read answer; else answer="Y"; fi
	if [ "$answer" == "y" ] || [ "$answer" == "Y" ]; then
		enableServiceonhost ${masterhost1} ${SERVICE_NAME}
		ret=$?
		if [ $ret -eq $FAILED ]; then
			echo -e "${RED}FAILED!${NORMAL}"
			INTERACTIVE=1
			echo -e "${RED}Please run nslookup ${SERVICE_NAME} to check service status,  then press anykey to continue ${NORMAL}"
			read anything
		else 
			echo -e "${GREEN}SUCCEED!${NORMAL}"
		fi
	fi
fi
