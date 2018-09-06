#!/bin/bash
MyUSER="backupuser"     # USERNAME
MyPASS="b@ckup0lny"       # PASSWORD
MyHOST="sfprodi6-z1"          # Hostname
MySLAVE="nyprodi7-z1"     # Slave Hostname
MyFILE="DRUPALPROD_checksum_result.log"

echo `date` 
. /home/mchen/.profile
# Linux bin paths, change this if it can not be autodetected via which command
MYSQL="$(which mysql)"
 
# Backup Dest directory, change this if you have someother location
DEST="$HOME/scripts/replication/result/"
 
# Main directory where backup will be stored
MBD="$DEST"
 
[ ! -d $MBD ] && mkdir -p $MBD || :
MyCHECKSUMFILE=$MBD$MyFILE
echo "">$MyCHECKSUMFILE

# Get hostname
HOST="$(hostname)"
 
# Get data in dd-mm-yyyy format
NOW="$(date +"%d-%m-%Y")"
 
# File to store current backup file
FILE=""
# Store list of databases
DBS=""
TABLES="" 

# DO NOT BACKUP these databases
#IGGY="test mysql information_schema drupal"
IGGY="mysql information_schema test"
 
# Gtet all database list first
DBS="$($MYSQL -u $MyUSER -h $MyHOST -p$MyPASS -Bse 'show databases')"
for db in $DBS
do
    skipdb=-1
    if [ "$IGGY" != "" ];
    then
	for i in $IGGY
	do
	    [ "$db" == "$i" ] && skipdb=1 || :
	done
    fi
 
    if [ "$skipdb" -eq -1 ] ; then
	echo "######################db is ${db}###########################"
	#TABLES="$($MYSQL -u $MyUSER -h $MyHOST -p$MyPASS $db -Bse 'show tables')"
	echo "$HOME/scripts/tools/percona-toolkit-1.0.1/bin/pt-table-checksum -u backupuser -pb@ckup0lny --sleep 1 --databases $db  $MyHOST $MySLAVE >> $MyCHECKSUMFILE" 
	$HOME/scripts/tools/percona-toolkit-1.0.1/bin/pt-table-checksum -u backupuser -pb@ckup0lny --sleep 1  --databases $db  $MyHOST $MySLAVE >> $MyCHECKSUMFILE 
    fi
done

$HOME/scripts/replication/recheck.pl > $HOME/scripts/replication/result/DRUPALPROD_CHECKSUM_RECHECK_result.log
echo `date`
