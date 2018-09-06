#!/bin/bash

#DEBUG=1
if ((DEBUG)); then set -x; fi

. $HOME/mysql.env

MHOST="localhost"  #host mysql need to be backedup
DBNAME="*"  #use '*' to backup all databases
TBNAME="users password_policy_history"   #use '*' to backup all tables inside the db
echo -n Password for backupuser:
read -s MPASS

MUSER="backupuser"
MYSQL="$(which mysql)"
MYSQLDUMP="$(which mysqldump)"
BAK="/var/mysql/backup/userupdate"
GZIP="$(which gzip)"
NOW=$(date +"%d-%m-%Y")
 
### See comments below ###
### [ ! -d $BAK ] && mkdir -p $BAK || /bin/rm -f $BAK/* ###
[ ! -d "$BAK" ] && mkdir -p "$BAK"
 
if [ "$DBNAME" == "*" ];then
	DBS="$MYSQL -u $MUSER -h $MHOST -p$MPASS -Bse \"show databases\""
else
	DBS="$MYSQL -u $MUSER -h $MHOST -p$MPASS -Bse \"show databases like '${DBNAME}%'\""
fi

echo "${DBS}"
all_dbs=`eval $DBS`
for db in $all_dbs
do
 FILE=$BAK/$db.$NOW
 echo "${db}"

	if [ $db != "sodb" ] && [ $db != "information_schema" ] && [ $db != "mysql" ] && [ $db != "test" ] && [ $db != "performance_schema" ] && [ $db != "slaptest" ]; then
		if [ "$TBNAME" == "*" ]; then
 			$MYSQLDUMP -u $MUSER -h $MHOST -p$MPASS --set-gtid-purged=OFF $db > $FILE
		else
 			$MYSQLDUMP -u $MUSER -h $MHOST -p$MPASS --set-gtid-purged=OFF $db $TBNAME> $FILE
		fi
	fi
done
 
