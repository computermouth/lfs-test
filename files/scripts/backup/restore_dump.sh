#!/bin/bash

#DEBUG=1
if ((DEBUG)); then set -x; fi

. $HOME/mysql.env

MUSER="bw_dbuser"
MHOST="localhost"  #host mysql need to be backedup

MYSQL="$(which mysql)"
MYSQLDUMP="$(which mysqldump)"
BAK="/var/mysql/backup/userupdate"
GZIP="$(which gzip)"
 
DBNAME="*"  #use '*' to backup all databases
TBNAME="users"   #use '*' to backup all tables inside the db
echo -n Password for ${MUSER}:
read -s MPASS

echo " "
echo "Timestmap for restore"
read TS
NOW=$(date +"%d-%m-%Y")

### See comments below ###
### [ ! -d $BAK ] && mkdir -p $BAK || /bin/rm -f $BAK/* ###
[ ! -d "$BAK" ] && mkdir -p "$BAK"
 
if [ "$DBNAME" == "*" ];then
	DBS="$MYSQL -u $MUSER -h $MHOST -p$MPASS -Bse \"show databases\""
else
	DBS="$MYSQL -u $MUSER -h $MHOST -p$MPASS -Bse \"show databases like '${DBNAME}%'\""
fi

#echo "${DBS}"
all_dbs=`eval $DBS`
for db in $all_dbs
do

	if [ $db != "sodb" ] && [ $db != "information_schema" ] && [ $db != "mysql" ] && [ $db != "test" ] && [ $db != "performance_schema" ] && [ $db != "slaptest" ]; then
		echo "restore ${db} from file ${BAK}/${db}.${TS}"
		if [ ! -f ${BAK}/${db}.${TS} ]; then
			echo "File ${BAK}/${db}.${TS} doesn't exist"
			continue
		fi
		if [ "$TBNAME" != "*" ]; then
 		        echo "mysql -u ${MUSER} -h ${MHOST} -pxxxx ${db} < ${BAK}/${db}.${TS} "
 		        mysql -u $MUSER -h $MHOST -p$MPASS $db < ${BAK}/${db}.${TS} 
		else
			echo "table name is not specified"
		fi
	fi
done
 
