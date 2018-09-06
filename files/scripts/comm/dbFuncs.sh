#!/bin/sh

#set CLOUD=1 to set as testing mode on cloud
CLOUD=0
OS=SOLARIS

#DB hostnames 

if [ "$CLOUD" -eq 1 ] ;then
	SFDB1="localhost--socket=/var/mysql/mysql01.sock--port=3307"
	SFDB2="localhost--socket=/var/mysql/mysql02.sock--port=3308"
	NYDB1="localhost--socket=/var/mysql/mysql03.sock--port=3309"
	NYDB2="localhost--socket=/var/mysql/mysql04.sock--port=3310"
	SFAEGIR="localhost--socket=/var/mysql/mysql01.sock--port=3307"
	NYAEGIR="localhost--socket=/var/mysql/mysql02.sock--port=3308"
else
	NYDB1="mysql1.nyprod"
	#NYDB2="nyprodi7-z1"
	SFDB1="mysql1.sfprod"
	#SFDB2="sfprodi7-z1"
	NYAEGIR="aegir1.nyprod"
	SFAEGIR="aegir1.sfprod"
fi



#MySQL root password, will be moved to command line args
#MySQL replication password for user 'repl'
MYSQL_REPL_PASSWORD="MYPASSWORD"
#The tempoary directory for MySQL data file transfer
TMP_DATA_DIR=\/tmp\/
DATENUM=`date +%Y%m%d-%H%M`

#get the current login user name
s_getcuruser()
{
 	if [ "$OS" = "LINUX" ]; then
        	curuser=`whoami`
	else
        	curuser=`logname`
	fi
        if [ "$CLOUD" -eq 1 ]; then
                curuser='mysql'
        fi


	echo $curuser
}

s_showSlaveStatus()
{
	dbName=$1
	if [ "$CLOUD" -eq 1 ]; then	
 		dbName=$(echo $1|sed 's/--/ --/g')
	fi

	echo ""
	echo "	${dbName}: show slave status..."
	echo "	mysql -u root -p$MYSQL_SVR_PASSWORD -h ${dbName} -e \"SHOW SLAVE STATUS\\G\""
	mysql -u root -p${MYSQL_SVR_PASSWORD} -h ${dbName} -e "SHOW SLAVE STATUS\G"
	SlaveRunning=1;
	# Any of SLAVE_SQL_RUNNING or SLAVE_IO_RUNNING is No or SECONDS_BEHIND_MASTER is NULL indicates broken slave 
	if [ `mysql -u root -p${MYSQL_SVR_PASSWORD} -h ${dbName} -e "SHOW SLAVE STATUS\G" | egrep -ci "SLAVE_IO_RUNNING: Yes|SLAVE_SQL_RUNNING: yes"` -ne 2 ]; then 
		return 0
	elif [ `mysql -u root -p${MYSQL_SVR_PASSWORD} -h ${dbName} -e "SHOW SLAVE STATUS\G" | egrep -ci "SECONDS_BEHIND_MASTER: NULL"` -eq 1 ] ; then
		return 0
	fi
	return 1 
}

s_getSlaveErrorcode()
{
        dbName=$1
	dbuser=$2
	dbpw=$3
        if [ "$CLOUD" -eq 1 ]; then
                dbName=$(echo $1|sed 's/--/ --/g')
        fi

        echo ""
        echo "  ${dbName}: show slave status..."
        echo "  mysql -u ${dbuser}  -p${dbpw} -h ${dbName} -e \"SHOW SLAVE STATUS\\G\" | grep -i \"Last_Errno:\" | awk '{print \$2}'"
	errcode=0
	ret=`mysql -u ${dbuser} -p${dbpw} -h ${dbName} -e "SHOW SLAVE STATUS\G" | grep -i "Last_Errno:" | awk '{print $2}'`
	echo $ret
	let ret=ret+0
        return $ret 
}

s_stopSlave()
{
	dbName=$1	

	if [ "$CLOUD" -eq 1 ]; then	
 		dbName=$(echo $1|sed 's/--/ --/g')
	fi

	echo ""
	echo "	$dbName: Stop Slave...."
	echo "	mysqladmin -u root -p$MYSQL_SVR_PASSWORD --host=$dbName stop-slave"

	if [ $DEBUG -eq 0 ]; then
		echo "	!!!!!!!!!!Stoping Slave on $dbName..."
		mysqladmin -u root -p${MYSQL_SVR_PASSWORD} --host=${dbName} stop-slave
		echo "	Done!"
	fi
	echo 	"$dbName: slave has been stopped"
	echo ""
}

s_startSlave()
{
	dbName=$1	

	if [ "$CLOUD" -eq 1 ]; then	
 		dbName=$(echo $1|sed 's/--/ --/g')
	fi

	echo ""
	echo "	$dbName: Start slave..."
	echo "	mysqladmin -u root -p$MYSQL_SVR_PASSWORD -h $dbName start-slave"
	if [ $DEBUG -eq 0 ]; then
		echo "	!!!!!!!!!!Starting Slave on $dbName...."
		mysqladmin -u root -p${MYSQL_SVR_PASSWORD} -h ${dbName} start-slave
		sleep 1 
		echo "	Done!"
	fi
	echo 	"$dbName: slave has been started"
	echo ""
}

s_syncData ()
{
	dbSource=$1
	dbTarget=$2
	resetMaster=$3
	dbbackupname=$1

	if [ "$CLOUD" -eq 1 ] ; then
 		dbSourceopt=$(echo $1|sed 's/--/ --/g')
 		dbTargetopt=$(echo $2|sed 's/--/ --/g')
		dbSource=localhost
		dbTarget=localhost
		dbsourceport=`expr substr $1 49 4`
		dbtargetport=`expr substr $2 49 4`
		dbbackupname=$dbsourceport
		myuser='root'
	else
		dbSourceopt=$dbSource
		dbTargetopt=$dbTarget
		dbsourceport=''
		dbtargetport=''
		myuser='mysql'
	fi

	echo ""
	echo "	Copying mysql database from $dbSource to $dbTarget..."
	echo "		$dbSource: Dumping data..."

	echo "		ssh ${myuser}@$dbSource \"mysqldump -u root -p$MYSQL_SVR_PASSWORD  -h $dbSourceopt --routines --flush-logs --single-transaction --master-data=1 --all-databases >"$TMP_DATA_DIR"mysqlbackup_${dbbackupname}_${DATENUM}.sql\""
	ssh ${myuser}@${dbSource} "mysqldump -u root -p${MYSQL_SVR_PASSWORD}  -h ${dbSourceopt} --routines --flush-logs --single-transaction --master-data=1 --all-databases > ${TMP_DATA_DIR}mysqlbackup_${dbbackupname}_${DATENUM}.sql "
	echo "		Done!"

	echo "		Transfering dump file from $dbSource to $dbTarget..."


	if [ "$CLOUD" -eq 1 ]; then
		echo "		 gzip -c ${TMP_DATA_DIR}mysqlbackup_${dbbackupname}_${DATENUM}.sql |  gunzip -c - > ${TMP_DATA_DIR}mysqlbackup_${dbbackupname}${dbtargetport}_${DATENUM}.sql"
		gzip -c ${TMP_DATA_DIR}mysqlbackup_${dbbackupname}_${DATENUM}.sql | gunzip -c - > ${TMP_DATA_DIR}mysqlbackup_${dbbackupname}${dbtargetport}_${DATENUM}.sql
	else
		echo "		ssh ${myuser}@${dbSource} \" gzip -c ${TMP_DATA_DIR}mysqlbackup_${dbbackupname}_${DATENUM}.sql | ssh $myuser@${dbTarget}\\\" gunzip -c - > ${TMP_DATA_DIR}mysqlbackup_${dbbackupname}_${DATENUM}.sql\\\"\""
		ssh ${myuser}@${dbSource} "gzip -c ${TMP_DATA_DIR}mysqlbackup_${dbbackupname}_${DATENUM}.sql | ssh ${myuser}@${dbTarget} \"gunzip -c - > ${TMP_DATA_DIR}mysqlbackup_${dbbackupname}_${DATENUM}.sql\""
	fi
	echo "		Done!"
	if [ $DEBUG -eq 0 ]; then
		echo "		!!!!!!!!!!Loading MySQL dump data from $dbSource into $dbTarget...."
		echo "		ssh ${myuser}@$dbTarget \"mysql -u root -p$MYSQL_SVR_PASSWORD -h $dbTargetopt < "$TMP_DATA_DIR"mysqlbackup_${dbbackupname}${dbtargetport}_${DATENUM}.sql\""
		ssh ${myuser}@${dbTarget} "mysql -u root -p${MYSQL_SVR_PASSWORD} -h ${dbTargetopt} < ${TMP_DATA_DIR}mysqlbackup_${dbbackupname}${dbtargetport}_${DATENUM}.sql"
		echo "		Done!"
		if [ $resetMaster -eq 1 ]; then
			echo "		!!!!!!!!!!Resetting master on $dbTarget...."
			echo "		mysql -u root -p$MYSQL_SVR_PASSWORD -h $dbTargetopt -e \"RESET MASTER;\""
			mysql -u root -p${MYSQL_SVR_PASSWORD} -h ${dbTargetopt} -e "RESET MASTER;"
			echo "		Done!"
		fi
	fi

	echo "	Data sychronization from $dbSource to $dbTarget is complete!"
	echo "  Cleaning tempoary files..."
	echo "  Cleaning file on the source server $dbSource"
	echo "ssh ${myuser}@${dbSource} \"rm ${TMP_DATA_DIR}mysqlbackup_${dbbackupname}_${DATENUM}.sql \""
	ssh ${myuser}@${dbSource} "rm ${TMP_DATA_DIR}mysqlbackup_${dbbackupname}_${DATENUM}.sql "
	echo "  Cleaning the tempoary files on the target server $dbTarget"
	echo "ssh ${myuser}@${dbTarget} \"rm ${TMP_DATA_DIR}mysqlbackup_${dbbackupname}${dbtargetport}_${DATENUM}.sql\""
	ssh ${myuser}@${dbTarget} "rm ${TMP_DATA_DIR}mysqlbackup_${dbbackupname}${dbtargetport}_${DATENUM}.sql"
	
}



s_replicationSetup()
{
	dbSlaveName=$1 
	dbMasterName=$2

	if [ "$CLOUD" -eq 1 ] ; then
		dbMasterPort=`expr substr $dbMasterName 49 4`
 		dbSlaveName=$(echo $1|sed 's/--/ --/g')
 		dbMasterName=$(echo $2|sed 's/--/ --/g')
	fi
	echo ""
	echo "	Setting up $dbSlaveName as a slave of $dbMasterName..."
	if [ $DEBUG -eq 0 ]; then
		echo "  !!!!!!!!!!Stop slave to ensure CHANGE MASTER succeed." 
		if [ "$CLOUD" -eq 1 ]; then
			s_stopSlave $1
	  	else	
			s_stopSlave $dbSlaveName
		fi
		sleep 1
		echo "	Done!"
		echo "	!!!!!!!!!!Resetting slave on $dbSlaveName...."
		echo "	mysql -u root -p$MYSQL_SVR_PASSWORD -h $dbSlaveName -e \"RESET SLAVE;\""
		mysql -u root -p${MYSQL_SVR_PASSWORD} -h ${dbSlaveName} -e "RESET SLAVE;"
		echo "	Done!"
		#sleep 1 
		echo "	!!!!!!!!!Changing master to $dbMasterName on $dbSlaveName"
		if [ "$CLOUD" -eq 1 ] ; then
			echo 	"	mysql -u root -p$MYSQL_SVR_PASSWORD -h $dbSlaveName -e \"CHANGE MASTER to MASTER_HOST='localhost',  MASTER_PASSWORD='$MYSQL_REPL_PASSWORD', MASTER_USER='repl', MASTER_PORT=$dbMasterPort;\""
			mysql -u root -p${MYSQL_SVR_PASSWORD} -h ${dbSlaveName} -e "CHANGE MASTER to MASTER_HOST='localhost',  MASTER_PASSWORD='${MYSQL_REPL_PASSWORD}', MASTER_USER='repl',MASTER_PORT=${dbMasterPort};"
		else
			echo 	"	mysql -u root -p$MYSQL_SVR_PASSWORD -h $dbSlaveName -e \"CHANGE MASTER to MASTER_HOST='$dbMasterName',  MASTER_PASSWORD='$MYSQL_REPL_PASSWORD', MASTER_USER='repl';\""
			mysql -u root -p${MYSQL_SVR_PASSWORD} -h ${dbSlaveName} -e "CHANGE MASTER to MASTER_HOST='${dbMasterName}',  MASTER_PASSWORD='${MYSQL_REPL_PASSWORD}', MASTER_USER='repl';"
		fi

		echo "	Done!"

	fi
	echo ""
}


s_resetMaster()
{
	dbName=$1
	
	if [ "$CLOUD" -eq 1 ]; then	
 		dbName=$(echo $1|sed 's/--/ --/g')
	fi

        echo "	mysql -u root -p$MYSQL_SVR_PASSWORD -h $dbName -e \"RESET MASTER;\""
        if [ $DEBUG -eq 0 ]; then
                echo "	!!!!!!!!!!Restting Master on $dbName...."
                mysql -u root -p${MYSQL_SVR_PASSWORD} -h ${dbName} -e "RESET MASTER;"
		echo "	Done!"
        fi

}

s_resetSlave()
{
 	dbName=$1
	if [ "$CLOUD" -eq 1 }; then	
 		dbName=$(echo $1|sed 's/--/ --/g')
	fi

        echo "	mysql -u root -p$MYSQL_SVR_PASSWORD -h $dbName -e \"RESET SLAVE;\""
        if [ $DEBUG -eq 0 ]; then
                echo "	!!!!!!!!!!Restting slave on $dbName...."
                echo 'mysql -u root -p${MYSQL_SVR_PASSWORD} -h ${dbName} -e "RESET SLAVE;"'
                mysql -u root -p${MYSQL_SVR_PASSWORD} -h ${dbName} -e "RESET SLAVE;"
		echo "	Done!"
        fi

}
