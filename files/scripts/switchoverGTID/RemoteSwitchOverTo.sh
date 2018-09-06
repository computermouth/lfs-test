#!/bin/bash

exec > >(tee  logs/RemoteSwitchover.log.`date +"%m%d%y_%H-%M"`) 2>&1

if [ -f ./inc/MySQL_HA.conf ]; then
        . inc/MySQL_HA.conf
else
        echo "Can not load inc/MySQL_HA.conf"
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
if [ $# -ne 1 ]; then
        echo "Usage: RemoteSwitchOverTo.sh ${LOC1}|${LOC2} "
        exit
fi

if [ "$1" != "${LOC1}" ]; then
        if [ "$1" != "${LOC2}" ];then
                echo "Usage: RemoteSwitchOverTo.sh ${LOC1}|${LOC2}"
                exit
        fi
fi


masterlocation=$1

if [ $SCNY -eq 0 ]; then # This is SF and SC switch over 
	if [ "$masterlocation" == "SF" ];then
        	masterhost1=${SFHOST1}
	        masterhost2=${SFHOST2}
	        slavehost1=${SCHOST1}
        	slavehost2=${SCHOST2}
	        slavelocation="SC"
	else
        	masterhost1=${SCHOST1}
	        masterhost2=${SCHOST2}
	        slavehost1=${SFHOST1}
        	slavehost2=${SFHOST2}
	        slavelocation="SF"
	fi

else  
	# This is SC and NY switch over
	if [ "$masterlocation" == "SC" ];then
        	masterhost1=${SCHOST1}
	        masterhost2=${SCHOST2}
	        slavehost1=${NYHOST1}
        	slavehost2=${NYHOST2}
	        slavelocation="NY"
	else
        	masterhost1=${NYHOST1}
	        masterhost2=${NYHOST2}
	        slavehost1=${SCHOST1}
        	slavehost2=${SCHOST2}
	        slavelocation="SC"
	fi
fi


. ./SwitchOver.sh $1 
