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
			cmd="INSERT INTO ${db}.users ( SELECT * FROM sodb.${db}_${TBNAME}) ON DUPLICATE KEY UPDATE pass=VALUES(pass);"
			echo "${cmd}"
 		        mysql -u $MUSER -h $MHOST -p$MPASS  -e "${cmd}" 
			TBNAME="passsword_policy_history"
			cmd="INSERT INTO ${db}.users ( SELECT * FROM sodb.${db}_${TBNAME}) ON DUPLICATE KEY UPDATE pass=VALUES(pass);"
			echo "${cmd}"
 		        mysql -u $MUSER -h $MHOST -p$MPASS  -e "${cmd}" 

		else
			echo "table name is not specified"
		fi
	fi
done
 
