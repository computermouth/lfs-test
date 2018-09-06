#!/bin/bash
exec > >(tee  logs/LocalStandby.log.`date +"%m%d%y_%H-%M"`) 2>&1

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
        echo "Usage: LocalStandbyFrom.sh SF|SC 1|2"
        exit
fi
if [ "$1" != "${LOC1}" ]; then
        if [ "$1" != "${LOC2}" ];then
                echo "Usage: LocalStandbyFrom.sh ${LOC1}|${LOC2} 1|2"
                exit
        fi
fi

if [ "$2" != "1" ]; then
        if [ "$2" != "2" ];then
                echo "Usage: LocalStandbyFrom.sh ${LOC1}|${LOC2} 1|2"
                exit
        fi
fi


MASTER=$1
CLUSTERNODE=$2

if [ $SCNY -eq 0 ]; then #this is SC and SF switch over
	if [ "${MASTER}" == "SC" ];then
       		if [ "${CLUSTERNODE}" == "1" ]; then
               		MASTERHOST1="${SCHOST1}"
	               	MASTERHOST2="${SCHOST2}"
       			SLAVEHOST1="${SFHOST1}"
	       		SLAVEHOST2="${SFHOST2}"
	       else
        	       	MASTERHOST1="${SCHOST2}"
               		MASTERHOST2="${SFHOST1}"
	       		SLAVEHOST1="${SFHOST2}"
       			SLAVEHOST2="${SCHOST1}"
       		fi
	else
       		if [ "${CLUSTERNODE}" == "1" ]; then
               		MASTERHOST1="${SFHOST1}"
	               	MASTERHOST2="${SFHOST2}"
	       		SLAVEHOST1="${SCHOST1}"
		       	SLAVEHOST2="${SCHOST2}"
       		else
               		MASTERHOST1="${SFHOST2}"
	               	MASTERHOST2="${SCHOST1}"
       			SLAVEHOST1="${SCHOST2}"
		       	SLAVEHOST2="${SFHOST1}"
       		fi

	fi
else  #This is SC and NY switch over
	if [ "${MASTER}" == "SC" ];then
       		if [ "${CLUSTERNODE}" == "1" ]; then
               		MASTERHOST1="${SCHOST1}"
	               	MASTERHOST2="${SCHOST2}"
       			SLAVEHOST1="${NYHOST1}"
	       		SLAVEHOST2="${NYHOST2}"
	       else
        	       	MASTERHOST1="${SCHOST2}"
               		MASTERHOST2="${NYHOST1}"
	       		SLAVEHOST1="${NYHOST2}"
       			SLAVEHOST2="${SCHOST1}"
       		fi
	else
       		if [ "${CLUSTERNODE}" == "1" ]; then
               		MASTERHOST1="${NYHOST1}"
	               	MASTERHOST2="${NYHOST2}"
	       		SLAVEHOST1="${SCHOST1}"
		       	SLAVEHOST2="${SCHOST2}"
       		else
               		MASTERHOST1="${NYHOST2}"
	               	MASTERHOST2="${SCHOST1}"
       			SLAVEHOST1="${SCHOST2}"
		       	SLAVEHOST2="${NYHOST1}"
       		fi

	fi
fi

. ./StandbyFrom.sh $1 $2 
