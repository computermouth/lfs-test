#!/bin/bash
exec > >(tee  logs/LocalSwitchOver.log.`date +"%m%d%y_%H-%M"`) 2>&1

if [ -f ./inc/MySQL_HA.conf ]; then
        . inc/MySQL_HA.conf
else
        echo "Can not load inc/MySQL_HA.conf"
        exit
fi

if [ $NODE -eq 1 ]; then
	echo "This is one node cluster, no local switch over is avaialbe ."
        exit
fi

if [ $SCNY -eq 1 ];then
        LOC1="SC"
        LOC2="NY"
else
        LOC1="SF"
        LOC2="SC"
fi


#Check command line options
if [ $# -ne 2 ]; then
        echo "Usage: SwitchOver.sh ${LOC1}|${LOC2} 1|2"
        exit
fi

if [ "$1" != "${LOC1}" ]; then
        if [ "$1" != "${LOC2}" ];then
                echo "Usage: SwitchOver.sh ${LOC1}|${LOC2} 1|2"
                exit
        fi
fi

if [ "$2" != "1" ]; then
        if [ "$2" != "2" ];then
                echo "Usage: SwitchOver.sh ${LOC1}|${LOC2} 1|2"
                exit
        fi
fi

masterlocation=$1
node=$2

if [ $SCNY -eq 1 ]; then #This is SC and NY switch over
	if [ "$masterlocation" == "SC" ];then
        	if [ "$node" == "1" ]; then
                	masterhost1=${SCHOST1}
	                masterhost2=${SCHOST2}
        	        slavehost1=${NYHOST1}
	                slavehost2=${NYHOST2}
        	else
                	masterhost1=${SCHOST2}
	                masterhost2=${NYHOST1}  
	                slavehost1=${NYHOST2}
        	        slavehost2=${SCHOST1}
        	fi
	        slavelocation="NY"
	else
	        if [ "$node" == "1" ]; then
	                masterhost1=${NYHOST1}
	                masterhost2=${NYHOST2}
	                slavehost1=${SCHOST1}
	                slavehost2=${SCHOST2}
	        else
	                masterhost1=${NYHOST2}
       			masterhost2=${SCHOST1}
                	slavehost1=${SCHOST2}
	                slavehost2=${NYHOST1}
        	fi
	        slavelocation="SC"
	fi
else
     #This is SF and SC switch over
	if [ "$masterlocation" == "SF" ];then
        	if [ "$node" == "1" ]; then
                	masterhost1=${SFHOST1}
	                masterhost2=${SFHOST2}
        	        slavehost1=${SCHOST1}
	                slavehost2=${SCHOST2}
        	else
                	masterhost1=${SFHOST2}
	                masterhost2=${SCHOST1}  
	                slavehost1=${SCHOST2}
        	        slavehost2=${SFHOST1}
        	fi
	        slavelocation="SC"
	else
	        if [ "$node" == "1" ]; then
	                masterhost1=${SCHOST1}
	                masterhost2=${SCHOST2}
	                slavehost1=${SFHOST1}
	                slavehost2=${SFHOST2}
	        else
	                masterhost1=${SCHOST2}
       			masterhost2=${SFHOST1}
                	slavehost1=${SFHOST2}
	                slavehost2=${SCHOST1}
        	fi
	        slavelocation="SF"
	fi
fi



. ./SwitchOver.sh $1 
