#!/bin/bash

exec > >(tee  logs/RemoteStandby.log.`date +"%m%d%y_%H-%M"`) 2>&1

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
        echo "Usage: RemoteStandbyFrom.sh ${LOC1}|${LOC2} "
        exit
fi
if [ "$1" != "${LOC1}" ]; then
        if [ "$1" != "${LOC2}" ];then
                echo "Usage: RemoteStandbyFrom.sh ${LOC1}|${LOC2}"
                exit
        fi
fi


MASTER=$1
#SC and NY switch over
if [ $SCNY -eq 1 ]; then
	if [ "${MASTER}" == "SC" ];then
        	MASTERHOST1="${SCHOST1}"
	        MASTERHOST2="${SCHOST2}"
	        SLAVEHOST1="${NYHOST1}"
	        SLAVEHOST2="${NYHOST2}"
	else
        	MASTERHOST1="${NYHOST1}"
	        MASTERHOST2="${NYHOST2}"
	        SLAVEHOST1="${SCHOST1}"
        	SLAVEHOST2="${SCHOST2}"
	fi
else # SC and SF switch over
	if [ "${MASTER}" == "SC" ];then
        	MASTERHOST1="${SCHOST1}"
	        MASTERHOST2="${SCHOST2}"
	        SLAVEHOST1="${SFHOST1}"
	        SLAVEHOST2="${SFHOST2}"
	else
        	MASTERHOST1="${SFHOST1}"
	        MASTERHOST2="${SFHOST2}"
	        SLAVEHOST1="${SCHOST1}"
        	SLAVEHOST2="${SCHOST2}"
	fi
fi
. ./StandbyFrom.sh $1 1 
