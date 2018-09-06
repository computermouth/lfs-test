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
NOW=$(date +"%d-%m-%Y")
 
DBNAME="*"  #use '*' to backup all databases
TBNAME="users"   #use '*' to backup all tables inside the db
echo -n Password for ${MUSER}:
read -s MPASS

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
	#echo "${db}"

	if [ $db != "sodb" ] && [ $db != "information_schema" ] && [ $db != "mysql" ] && [ $db != "test" ] && [ $db != "performance_schema" ] && [ $db != "slaptest" ]; then
		if [ "$TBNAME" != "*" ]; then
			TBNAME="users"
			cmd="CREATE TABLE if not exists sodb.${db}_${TBNAME} like ${db}.${TBNAME};truncate table sodb.${db}_${TBNAME}; set session sql_mode='NO_AUTO_VALUE_ON_ZERO';INSERT INTO sodb.${db}_${TBNAME} select * from ${db}.${TBNAME};select name from sodb.${db}_${TBNAME} where name not in ( select name from ${db}.${TBNAME});"
			echo "${cmd}"
 		        mysql -u $MUSER -h $MHOST -p$MPASS -e "${cmd}"
			TBNAME="password_policy_history"
			cmd="CREATE TABLE if not exists sodb.${db}_${TBNAME} like ${db}.${TBNAME};truncate table sodb.${db}_${TBNAME}; set session sql_mode='NO_AUTO_VALUE_ON_ZERO';INSERT INTO sodb.${db}_${TBNAME} select * from ${db}.${TBNAME};select pid from sodb.${db}_${TBNAME} where pid not in ( select pid from ${db}.${TBNAME});"
			echo "${cmd}"
 		        mysql -u $MUSER -h $MHOST -p$MPASS -e "${cmd}"
		else
			echo "table name is not specified"
		fi
	fi
done
 
