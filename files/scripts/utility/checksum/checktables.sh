#!/bin/bash
MyUSER="backupuser"     # USERNAME
MyPASS="b@ckup0lny"       # PASSWORD
#MyFILE="PROD_checksum_result.log"

MyPROJECT=$1
MyHOST=$2
MySLAVE=$3
#MyUSER=$4
#MyPASS=$5

. $HOME/mysql.env

if [ "$#" -lt 3 ];then
	echo "Usage: checktables.sh cluster_name  mast_hostname  slave_hostname"
	exit 0
fi
MyFILE=${MyPROJECT}"_checksume_result.log"
echo `date` 
echo $PATH
# Linux bin paths, change this if it can not be autodetected via which command
MYSQL="$(which mysql)"
 
# Backup Dest directory, change this if you have someother location
SCRIPTDIR="${HOME}/scripts/utility/checksum/"
DEST="${HOME}/scripts/utility/checksum/result/"
 
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
IGGY="mysql information_schema test bwc performance_schema workflow mem"
 
# Gtet all database list first
DBS="$($MYSQL -u $MyUSER -h $MyHOST -p$MyPASS -Bse 'show databases')"
#${HOME}/scripts/utility/checksum/recheck.pl -u $MyUSER -p $MyPASS -f $MyCHECKSUMFILE -m $MyHOST -s $MySLAVE> ${DEST}$(MyPROJECT}PROD_CHECKSUM_RECHECK_result.log
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
	echo "pt-table-checksum -u $MyUSER -pxxxxxx  --databases $db  $MyHOST $MySLAVE >> $MyCHECKSUMFILE" 
	pt-table-checksum -u ${MyUSER} -p${MyPASS}   --databases $db  $MyHOST $MySLAVE >> $MyCHECKSUMFILE 
    fi
done

echo " Now start recheck progress..."
#recheckcmd="${SCRIPTDIR}recheck.pl -u ${MyUSER} -p ${MyPASS} -f ${MyCHECKSUMFILE} -m ${MyHOST} -s ${MySLAVE}> ~/scripts/utility/checksum/result/${MyPROJECT}PROD_CHECKSUM_RECHECK_result.log"
#recheckcmd="${SCRIPTDIR}recheck.pl "
recheckcmd="${SCRIPTDIR}recheck.pl -u ${MyUSER} -p ${MyPASS} -f ${MyCHECKSUMFILE} -m ${MyHOST} -s ${MySLAVE}"
#recheckcmdarg="-u ${MyUSER} -p ${MyPASS} -f ${MyCHECKSUMFILE} -m ${MyHOST} -s ${MySLAVE}"
echo "recheck command is $recheckcmd "
`$recheckcmd > ${DEST}${MyPROJECT}_CHECKSUM_RECHECK_result.log `
echo `date`
