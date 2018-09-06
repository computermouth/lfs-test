#!/bin/bash
#########################################################################################
#	Name: alldata_backup.sh                   				   	#
#		Backup either Drupal or Aegir MySQL database servers.			#
#	Usage: alldata_backup.sh Drupal|Aegir						#
#		The servers are given in the drupal_servers or aegir_servers		#
#		This script will be running as a cron job on nyprodi7-z1 during midnight#
#	Output:  servername:/var/mysql/backup/mysql-AAA__BBB_CCC_DDDD.sql.gz		#
#			AAA: data or bin						#
#			BBB: Aegir or Drupal						#
#			CCC: server name sfprodi6-z1 etc				#
#			DDDD:date with date and time hh:mm				#
#	Author:  Min Chen								#
#	Last update: 9/27/2012								#
#########################################################################################

BASEDIR=~/scripts/backup
trap 'increment' 2

increment()
{
  echo "Caught SIGINT ..."
  echo "Okay, I'll quit ..."
  exit 1
}


if [ -f $HOME/mysql.env ] ; then
	. $HOME/mysql.env
else
    echo "ALARM: $HOME/mysql.env doesn't exist!!!, this script may not work properly." 
fi

if [ -f $SCRIPT_PATH/backup/backup.conf ]; then
	if [ $# -gt 0 ]; then  
		. $SCRIPT_PATH/backup/backup.conf $1
	else
		. $SCRIPT_PATH/backup/backup.conf
	fi
else
	echo "ALARM: $SCRIPT_PATH/backup/backup.conf is missing, please contact the Administrctor."
	exit 1
fi

if [ -f $SCRIPT_PATH/backup/do_backup.sh ]; then
	. $SCRIPT_PATH/backup/do_backup.sh
else
	echo "ALARM: $SCRIPT_PATH/backup/do_backup.sh is missing, please contact the Administrctor."
	exit 1
fi
env
datum=`date +%Y%m%d-%H%M`


#########################################################
#       Main backup process starts			#  
#########################################################
echo -e "\n\n\n\n ############MySQL Daily backup process is started....##########\n"
echo `date`


echo -e "\n###MySQL daily enterprise mysqlback  is started....###\n"
totalServers=${#dbs_hot[@]}
totalServers=`expr $totalServers - 1`
count=0
while [ "$count" -le "$totalServers" ]
do
	echo "${dbs_hot[${count}]}"
	hasSpace  ${SSH_USER} ${dbs_hot[${count}]} $BACKUP_VOLUMN $BACKUP_DIR
	result=$?
	if [ "$result" -eq 0 ]; then 
		echo "Backup on ${dbs_dump[${count}]} is terminated due to lack of disk space."
    	else
		backup_hot ${SSH_USER} ${dbs_hot[${count}]} ${MYSQL_SVR_USER} ${MYSQL_SVR_PASSWORD} ${BACKUP_DIR} "${MYSQLBACKUP_OPTIONS}" $dbType $datum
       		 check_result $?
	fi
	echo "Clean up the old backup copies."
	cleanup_hot ${SSH_USER} ${dbs_hot[${count}]} ${RETENTION} ${BACKUP_DIR}
	#check_result $?
	#if [ "$?" == "0" ];then
	#   exit;
	#fi
	count=`expr ${count} + 1`
done
echo `date`
echo -e "\n###MySQL daily enterprise mysqlback is complete. ###\n"

echo -e "\n###MySQL Daily mysqldump  is started....###\n"
totalServers=${#dbs_dump[@]}
totalServers=`expr $totalServers - 1`
count=0
while [ "$count" -le "$totalServers" ]
do
	echo "${dbs_dump[${count}]}"
	hasSpace  $SSH_USER ${dbs_dump[${count}]} $BACKUP_VOLUMN $BACKUP_DIR
	result=$?
	if [ "$result" -eq 0 ]; then 
		echo "ALARM!!!:Backup on ${dbs_dump[${count}]} is terminated due to lack of disk space."
	else
		backup_dump $SSH_USER ${dbs_dump[${count}]} $MYSQL_SVR_USER $MYSQL_SVR_PASSWORD $BACKUP_DIR $dbType $datum "${MYSQLDUMP_OPTIONS}"
        check_result $?
	fi
	#s_binlogBackup ${dbs_dump[${count}]}
	cleanup_dump $SSH_USER ${dbs_dump[${count}]} $BACKUP_DIR $RETENTION
	#check_result $?
	count=`expr ${count} + 1`
done
echo `date`
echo -e "\n###MySQL daily mysqldump is complete###\n"


echo -e "\n###MySQL daily binlog backup is started....###\n"
totalServers=${#dbs_binlog[@]}
totalServers=`expr $totalServers - 1`
count=0
while [ "$count" -le "$totalServers" ]
do
	echo "${dbs_binlog[${count}]}"
	backup_binlog ${SSH_USER} ${dbs_binlog[${count}]} ${dbType} ${DATA_DIR} ${BACKUP_DIR} ${datum}
	#binlog is constantly changing, so tar binlog always return error, ignore error message from tar binlog 
        #check_result $?
	#if [ "$?" == "0" ];then
	#   exit;
	#fi
	echo "Clean up the old backup copies."
	cleanup_binlog ${SSH_USER} ${dbs_binlog[${count}]} ${BACKUP_DIR} ${RETENTION}  
	check_result $?
	#if [ "$?" == "0" ];then
	#   exit;
	#fi
	count=`expr ${count} + 1`
done
echo `date`
echo -e "\n###MySQL daily binlog backup is complete.###\n"

echo -e "\n\n ############MySQL Daily backup process is complete.##########\n\n"
