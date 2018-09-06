#!/bin/bash


#Load configuration file for HA scripts
if [ -f inc/MySQL_HA.conf ]; then
	. inc/MySQL_HA.conf
else
	echo "Can't load MySQL_HA.conf."
	exit
fi



#run the given command on the hosti with ${SSH}
runcmdonhost()
{

   hostname=$1
   cmd=$2
   needsudo=`expr substr "$cmd" 1 4`


   if [ $DEBUG ] ;then
	scmd="${cmd/$PWD/xxx}"
	sscmd="${scmd/$REPLPWD/xxxx}"
        echo "     [DEBUG]$0:runcmdonhost:  ${SSH} [-t] ${USER}@${hostname} \"${sscmd}\""
   fi
   #cmd=""
   if [ "$TEST" -ne 1  ]; then
        if [ "$needsudo" == "sudo" ]; then
                ${SSH} -t ${USER}@${hostname} "${cmd}"
        else
                ${SSH}  ${USER}@${hostname} "${cmd}"
        fi
       #echo "TEST"
   else
        echo "This is TEST mode, no command will be issued."
   fi
}

verifyResult ()
{
	host=$1
	vcmd=$2
	lookret=$3


       	scmd="${vcmd/$PWD/xxx}"
        sscmd="${scmd/$REPLPWD/xxxx}"
			
 

        echo "Verifing the result on $host $sscmd...."
	${SSH} ${USER}@${host} "$vcmd" | grep "$lookret"

	result=$?
	if [ $result -eq 0 ]; then
        	echo -e  "${GREEN}SUCCEED!${NORMAL}"
	else 
        	echo -e  "${RED}FAILED!${NORMAL}"
		INTERACTIVE=1
		alertEmail "Verficiation Failed ${host}:${sscmd}"
		echo "Switch Over verfication failed ${host}:${sscmd}" | mailx -s "${CLUSTERNAME}  Switch Over -verification failed" ${ALERTEMAIL} 
	fi
	return $result
}

getLogFileInGrp()
{
	master=$1
	pwd=$2

	echo "Get INNODB_LOG_FILES_IN_GROUP"
	sSQL="show global variables like 'innodb_log_files_in_group'\G"

        echo "${SSH} ${USER}@${master} \"mysql -u ${ROOT} -p'xxx' -e \"${sSQL}\"\""
        ret=`${SSH} ${USER}@$master "mysql -u ${ROOT} -p'${pwd}' -e \"${sSQL}\""  | sed 's/Value:*//'` 
        if [ -z $ret ]; then
                echo "Can't get INNODB_LOG_FILES_IN_GROUP. Using the default one"
		_LogNumInGrp=$INNODB_LOG_FILES_IN_GROUP
        else
		_LogNumInGrp=$ret
        fi
	return _LOgNumInGrp

	
}
isGTIDEnabled()
{
	master=$1
	pwd=$2

	echo -e "Check if $CLUSTERNAME has GTID enabled...\n"
	sSQL="show global variables like 'GTID_MODE'\G;"

	echo "${SSH} ${USER}@${master} \"mysql -u ${ROOT} -p'xxx' -e \"${sSQL}\"\""
	${SSH} ${USER}@$master "mysql -u ${ROOT} -p'${pwd}' -e \"${sSQL}\""  | grep "Value: ON"
	result=$?
	if [ $result -eq 0 ]; then
		echo "GTID is enabled"
		return $YES
        else
		echo "GTID is disabled"
		return $NO
	fi
}

#call mysqlbackup to backup the given host
#mysqlbackup will lock the database for a minutes depends on the number of files. --no-locking will leave the backup without GTID file. During Switchover, don't use no-locking parameter for mysqlback
do_backup()
{
        hostname=$1
        pwd=$2
        echo `date`"- backup master ${hostname} start..."
#echo "${SSH} ${MASTERHOST} \"mysqlbackup -u ${ROOT} -p${PWD} --compress --no-history-logging --backup-dir=${BACKUP_DIR_TEMP} backup"
        cmd=". ~/mysql.env; mysqlbackup -u ${ROOT} -p'${pwd}' --compress --no-history-logging --backup-dir=${BACKUP_DIR_TEMP} --backup-image=${BACKUP_DIR_TEMP}/${hostname}_${DATENUM}.img.gz backup-to-image"
	runcmdonhost "$hostname" "$cmd"
	echo "Backup on $hostname is complete."

	#verify the backup file
	vcmd="ls -l ${BACKUP_DIR_TEMP}/${hostname}_${DATENUM}.img.gz"
	str="${BACKUP_DIR_TEMP}/${hostname}_${DATENUM}.img.gz"
	verifyResult "$hostname" "$vcmd" "$str"
	ret=$?
	return $ret
}

##############################################################
#         Setup all slaves as chain replication with GTID    #
#         CHANGE MASTER TO                                   #
##############################################################
setSlaves()
{
        args=($@)
        master=$1
        pwd=$2
        len=$#

	#isGTIDEnabled $master
	#GTID=$?
	#if [ GTID -eq $NO ];then
	#	setSlavesWOGTID
	#fi
        for ((i=2; i < len; i++))
        do
                slave=${args[$i]}

                #setup slave ${slave} as the slave as ${master}
                echo "Setup ${slave} as the slave of ${master}? (y/n)?"

        	#setup chain slaves from the given master 
	        sSQL="STOP SLAVE;CHANGE MASTER TO MASTER_HOST='"${master}"',MASTER_PASSWORD='"${REPLPW}"',MASTER_USER='"${REPLUSER}"', MASTER_AUTO_POSITION=1;"
		#if this is a graceful switch over, no need to reset slave, just let slave to negociate with master for start point. GRACEFUL is defined in MySQL_HA.conf by default =0 , it can be changed during the standby process by user otherwise reset slave, start over again.
 
		if [ $GRACEFUL -eq 0 ]; then
			slaveSQL="STOP SLAVE; RESET SLAVE;"${sSQL}
		else
			slaveSQL=$sSQL
		fi

                if [ $INTERACTIVE -ne 0 ]; then read answer; else answer="Y"; fi
                if [ "$answer" == "y" ] || [ "$answer" == "Y" ]; then
                	echo "${SSH} ${USER}@${slave} \"mysql -u ${ROOT} -p'xxxxx' -e \"${slaveSQL}\"\""
                	${SSH} ${USER}@${slave} "mysql -u ${ROOT} -p'${pwd}' -e \"${slaveSQL}\""
                fi
        
		echo "Start slave on slave ${slave} ? (y/n)?"
        	if [ $INTERACTIVE -ne 0 ]; then read answer; else answer="Y"; fi
        	if [ "$answer" == "y" ] || [ "$answer" == "Y" ]; then
                	startSlave "${master}" "$slave" "$pwd"
        	fi
                master=$slave

        done

}

#############################################################
#    Restore data from master to the slave                  #
############################################################
createSlave()
{
        args=($@)
        master=$1
        pwd=$2
        len=$#

        #transfer backup to slave
        for ((i=2; i < len; i++))
        do
                slave=${args[$i]}

                #transfer the backup file from master to slave
                echo "Transfer backup from ${master} to ${slave}? (y/n)?"
                if [ $INTERACTIVE -ne 0 ]; then read answer; else answer="Y"; fi
                if [ "$answer" == "y" ] || [ "$answer" == "Y" ]; then
                        fileTransfer $master $slave
                fi
                master=$slave

        done

        #setup slave
	master=$1
        for ((i=2; i < len; i++))
        do
                slave=${args[$i]}
		if [ $i -eq 2 ];then
			_firstSlave=$YES
		else
			_firstSlave=$NO
		fi

                echo "Setup slave ${slave}? (y/n)?"
                if [ $INTERACTIVE -ne 0 ]; then read answer; else answer="Y"; fi
                if [ "$answer" == "y" ] || [ "$answer" == "Y" ]; then
                        restore_onslavehost ${master} ${slave} "${pwd}" $_firstSlave
                fi
                master=$slave
	done
}


##########################################################################
# Transfer a file from the given source host to the desctination host    #
# using rsync and ssh                                                    #
##########################################################################
fileTransfer ()
{
        SOURCE=$1
        DEST=$2

        echo `date`"- Transfer the backup file from master ${SOURCE} to slave ${DEST} start..."
        #echo "${SSH} ${USER}@${DEST} \"rsync -avz -e ${SSH}  --progress ${USER}@${SOURCE}:${BACKUP_DIR}/${DATEDIR}  ${BACKUP_DIR}\""
        #${SSH} ${USER}@${DEST} "rsync -avz -e ${SSH} --progress  ${USER}@${SOURCE}:${BACKUP_DIR}/${DATEDIR}  ${BACKUP_DIR}"
        cmd="rsync -avz -e \"${SSH}\" --progress  ${USER}@${SOURCE}:${BACKUP_DIR}/${DATEDIR}  ${BACKUP_DIR}"
	runcmdonhost "$DEST" "$cmd"
        echo `date`"- Transfer the backup  files to the slave ${DESC} complete"

	#verify the backup file
	vcmd="ls -l ${BACKUP_DIR}/${DATEDIR}"
        str="_${DATENUM}.img.gz"

	verifyResult "$DEST" "$vcmd" "$str"
	ret=$?
	return $ret
}

################################################################
#      extract mysqlbacup image to the backup directory        #
################################################################
extractBackupImage()
{
   	host=$1
   	cmd=". ~/mysql.env; mysqlbackup  --backup-image=${BACKUP_DIR_TEMP}/${MASTERHOST}_${DATENUM}.img.gz --backup-dir=${BACKUP_DIR}/${DATEDIR} extract"
   	runcmdonhost "$host" "$cmd"
	echo "Extract backupimage on $host is complate."

	#verify the backup file
	vcmd="ls -l ${BACKUP_DIR}/${DATEDIR}/datadir/ibdata1.ibz"
	str="ibdata1.ibz"
	verifyResult "$host" "$vcmd" "$str"
	ret=$?
	return $ret
}

#######################################################################
#    apply log to the backup to make the backup ready for restore     #
#######################################################################
applyLog()
{
	host=$1
   	echo `date`"Apply log to the backup file on the slave ${host} start..."
  	cmd=". ~/mysql.env; mysqlbackup --uncompress --backup-dir=${BACKUP_DIR}/${DATEDIR} apply-log"
	   #echo "${SSH} ${USER}@${host} \"${cmd}\""
	   #${SSH} ${USER}@${host} "${cmd}"
   	runcmdonhost "$host" "$cmd"
   	echo `date`"Run apply log to the backup file on the slave ${host} complete."

	vcmd="ls -l ${BACKUP_DIR}/${DATEDIR}/datadir/ibdata1"
	str="ibdata1"
	verifyResult "$host" "$vcmd" "$str"
	ret=$?
	return $ret
}

##############################################################################
#clean up the backu pimage file to save space once the image is extracted    #
##############################################################################
cleanImageFile()
{
   host=$1
   cmd=". ~/mysql.env; rm ${BACKUP_DIR_TEMP}/${MASTERHOST}_${DATENUM}.img.gz"
   runcmdonhost "$host" "$cmd"
   return 1
}

##############################################################################
#remove the compressed data file once the backup is uncompressed             #
##############################################################################
cleanCompressedFile()
{
   host=$1
   cmd=". ~/mysql.env; rm ${BACKUP_DIR_TEMP}/datadir/*.ibz"
   runcmdonhost "$host" "$cmd"
   return 1
}


##############################################################################
#rest on slave to get fresh start                                            #
##############################################################################
resetMaster()
{
        host=$1
	pwd=$2
        echo `date`"Reset Master on  ${host} start..."
        cmd="mysql -u ${ROOT} -p'${pwd}' -e \"STOP SLAVE;RESET MASTER;RESET SLAVE;\""
	runcmdonhost "$host" "$cmd"
        #echo "${SSH} ${USER}@${host} \"${cmd}\""
        #${SSH} ${USER}@${host} "${cmd}"
        echo `date`"RESET Master on the slave ${host} complete."

	vcmd="mysql -u ${ROOT} -p'$pwd' -e \"show slave status\G\""
	str="Slave_IO_Running: No"
	verifyResult "$host" "$vcmd" "$str"
	ret=$?
	return $ret
}

##############################################################################
#                Stop MySQL service                                          #
##############################################################################
stopMySQL()
{
        host=$1
        echo `date` "Shutdown the slave ${host} mysql for restore start...."

        cmd="sudo /etc/init.d/mysql stop"
        runcmdonhost "${host}" "${cmd}"
	vcmd="sudo /etc/init.d/mysql status"
	str="running"
	verifyResult "$host" "$vcmd" "$str"
	ret=$?
        echo `date` "Shutdown the slave ${host} mysql for restore complete"
	return $ret
}

##############################################################################
#                restore database with master data                          #
##############################################################################
dbRestore()
{
        host=$1

        echo `date`"Restore the backup file from the master ${MASTERHOST} to the slave ${host} start..."
        #copy-back
	cmd=". ~/mysql.env;mysqlbackup --defaults-file=/etc/my.cnf --innodb-log-files-in-group=${INNODB_LOG_FILES_IN_GROUP} --innodb-data-file-path='${INNODB_DATA_FILE_PATH}' --backup-dir=${BACKUP_DIR}/${DATEDIR} --force copy-back"
        #remove, mv
        #cmd=". ~/mysql.env; rm -rf ${DATA_DIR}/* && mv ${BACKUP_DIR}/${DATEDIR}/datadir/* ${DATA_DIR}/"
        echo "${SSH} ${USER}@${host} \"${cmd}\""
        runcmdonhost "${host}" "${cmd}"
        #${SSH} ${USER}@${host} "${cmd}"
        echo `date`"Restore the backup file from the master ${MASTERHOST} to the slave ${host} complete"

	vcmd="find ${DATA_DIR}/ -name ibdata1 "
	str="ibdata1"
	verifyResult "$host" "$vcmd" "$str"
	ret=$?
	return $ret
}

##############################################################################
#                Start MySQL service                                          #
##############################################################################
startMySQL()
{
        host=$1

        echo `date`"Start slave ${host} MySQL ..."
        cmd="sudo /etc/init.d/mysql start"
        echo "${SSH} ${USER}@${host} \"${cmd}\""
        #${SSH} -t ${USER}@${host} "${cmd}"
        runcmdonhost "${host}" "${cmd}"

    
        echo `date`"Slave ${host} is restarted"

	vcmd="sudo /etc/init.d/mysql status"
	str="running"
	verifyResult "$host" "$vcmd" "$str"
	ret=$?
	return $ret

}
###########################################################
#    Function:  startSlave                                #
#          stop slave on the given host                   #
#    Parameters:                                          #
#          $1:$masterhost master hostname                 #
#          $2:$slavehost slave hostname                   #
#          $3:$pwd   mysql root password                  #
#  Reference to the following variables in conf:          #
#          ${ROOT}                                        #
#  Call functions:                                        #
#          runcmdonhost $host $cmd                        #
#          verifyResult $host $vcmd  $str                 #
###########################################################
startSlave()
{
	masterhost=$1
	slavehost=$2
        pwd=$3

        cmd="mysql -u ${ROOT} -p'${pwd}' -e \"start slave;\""
        runcmdonhost "${slavehost}" "${cmd}"
	sleep 10 

	vcmd="mysql -u ${ROOT} -p'$pwd' -e \"show slave status\G\""
	str="Master_Host: ${masterhost}"
	str="Slave_IO_Running: Yes"
	verifyResult "$slavehost" "$vcmd" "$str"
	ret=$?
	str="Slave_SQL_Running: Yes"
	verifyResult "$slavehost" "$vcmd" "$str"
	ret1=$?

        #return code need be changed to be more readable 
        if [ $ret -eq 1 ] || [ $ret1 -eq 1 ];then
		return 1 
	else
		return 0 
	fi
}

###########################################################
#    Function:  StopSlave                                 #
#          stop slave on the given host                   #
#    Parameters:                                          #
#          $1:$slavehost slave hostname                   #
#          $2:$pwd   mysql root password                  #
#  Reference to the following variables in conf:          #
#          ${ROOT}                                        #
#  Call functions:                                        #
#          runcmdonhost $host $cmd                        #
#          verifyResult $host $vcmd  $str                 #
###########################################################
stopSlave()
{
	slavehost=$1
        pwd=$2

        cmd="mysql -u ${ROOT} -p'${pwd}' -e \"stop slave;\""
        runcmdonhost "${slavehost}" "${cmd}"
	sleep 10 

	vcmd="mysql -u ${ROOT} -p'$pwd' -e \"show slave status\G\""
	str="Slave_IO_Running: No"
	verifyResult "$slavehost" "$vcmd" "$str"
	ret=$?
	str="Slave_SQL_Running: No"
	verifyResult "$slavehost" "$vcmd" "$str"
	ret1=$?

       #return code need be changed to be more readable
        #if [ $ret -ne 0 ] &&  [ $ret1 -ne 0 ] && [ "$slavehost" == "$SCHOST1" ];then  # its possible show slave status return "" since the primary server has never been setup as s alve
        if [ $ret -ne 0 ] &&  [ $ret1 -ne 0 ]; then  # its possible show slave status return "" since the primary server has never been setup as s alve
		echo "#####slave host is ${slavehost}"
		echo "####schost1 is ${SCHOST1}"
		verifyResult "$slavehost" "$vcmd" ""
                return $ret 
        else
                return $ret||$ret1 
        fi

	#return $ret
}

alertEmail()
{
	msg=$1
	echo "in alertEmail"
	echo "echo $msg | mailx -s \"$0\" ${ALERTEMAIL}"
	echo $msg | mailx -s "$0" "${ALERTEMAIL}" 
}

###########################################################
#    Function:  restore_onslavehost                       #
#          restore enterprise backup image on slave host  #
#    Parameters:                                          #
#          $1:$master master hostname                     #
#          $2:$slavehost slave  hostname                  #
#          $3:${pwd} root password                        #
#          $4:$_firstSlave if this is the first slave     #
#   Reference to the following variables in conf          #
#         $SSH : complete ssh command                     #
#         $ROOT: Mysql system user name                   #
#         $INTERACTIVE: if the script should be           #
#                   exected without interactive           #
#         $BACKUP_DIR_TEMP: backup directory on slave     #
#  Call functions:                                        #
#          extractBackupImage $slavehost                  #
#          cleanImageFile $slavehost                      #
#          applyLog $slavehost                            #
#          cleanCompressedFile $slavehost                 #
#          resetMaster "$slavehost" "$pwd"                #
#          stopMySQL "${slavehost}"                       #
#          dbRestore "${slavehost}"                       #  
#          startMySQL  "${slavehost}"                     #
#          startSlave "${master}" "$slavehost" "$pwd"     #
###########################################################
restore_onslavehost()
{
        master=$1
        slavehost=$2
        pwd=$3
	_firstSlave=$4
        echo "Extract backup image on slave ${slavehost}? (y/n)?"

        if [ $INTERACTIVE -ne 0 ]; then read answer; else answer="Y"; fi
        if [ "$answer" == "y" ] || [ "$answer" == "Y" ]; then
                extractBackupImage $slavehost
        fi

        echo "remove the image file on slave ${slavehost} to save space? (y/n)?"
        if [ $INTERACTIVE -ne 0 ]; then read answer; else answer="Y"; fi
        if [ "$answer" == "y" ] || [ "$answer" == "Y" ]; then
           cleanImageFile $slavehost
        fi

        echo "Apply log to the backup file on slave ${slavehost}? (y/n)?"
        if [ $INTERACTIVE -ne 0 ]; then read answer; else answer="Y"; fi
        if [ "$answer" == "y" ] || [ "$answer" == "Y" ]; then
                applyLog $slavehost
        fi

        echo "remove the compressed idata file on slave ${slavehost} to save space? (y/n)?"
        if [ $INTERACTIVE -ne 0 ]; then read answer; else answer="Y"; fi
        if [ "$answer" == "y" ] || [ "$answer" == "Y" ]; then
           cleanCompressedFile $slavehost
        fi


        echo "To Clean up master binary log on ${slavehost}? (y/n)?"
        if [ $INTERACTIVE -ne 0 ]; then read answer; else answer="Y"; fi
        if [ "$answer" == "y" ] || [ "$answer" == "Y" ]; then
                resetMaster "$slavehost" "$pwd"
        fi

        echo "Shutdown MySQL on slave ${slavehost} for restore? (y/n)?"
        if [ $INTERACTIVE -ne 0 ]; then read answer; else answer="Y"; fi
        if [ "$answer" == "y" ] || [ "$answer" == "Y" ]; then
                stopMySQL "${slavehost}"
        fi

        echo "Restore backup from master $MASTERHOST to slave ${slavehost} ? (y/n)?"
        if [ $INTERACTIVE -ne 0 ]; then read answer; else answer="Y"; fi
        if [ "$answer" == "y" ] || [ "$answer" == "Y" ]; then
                dbRestore "${slavehost}"
        fi

        echo "Start MySQL on slave ${slavehost} ? (y/n)?"
        if [ $INTERACTIVE -ne 0 ]; then read answer; else answer="Y"; fi
        if [ "$answer" == "y" ] || [ "$answer" == "Y" ]; then
                startMySQL  "${slavehost}"
        fi

    	isGTIDEnabled "$master" "$pwd"
        isGTID=$?
	echo "Result isGTID=${isGTID}"

        echo "Change master on slave ${slavehost} ? (y/n)?"
        if [ $INTERACTIVE -ne 0 ]; then read answer; else answer="Y"; fi
        if [ "$answer" == "y" ] || [ "$answer" == "Y" ]; then
		if [ $isGTID -eq $YES ];then
                	echo "${SSH} ${USER}@${slavehost} \"mysql -u ${ROOT} -p'xxx' -e \"RESET MASTER;STOP SLAVE;RESET SLAVE;CHANGE MASTER TO MASTER_HOST='${master}',MASTER_PASSWORD='${REPLPW}',     MASTER_USER='${REPLUSER}', MASTER_AUTO_POSITION=1;source ${BACKUP_DIR_TEMP}/meta/backup_gtid_executed.sql\"\""
                	${SSH} ${USER}@${slavehost} "mysql -u ${ROOT} -p'${pwd}' -e \"RESET MASTER;STOP SLAVE;RESET SLAVE;CHANGE MASTER TO MASTER_HOST='${master}',MASTER_PASSWORD='${REPLPW}',     MASTER_USER='${REPLUSER}',MASTER_AUTO_POSITION=1;source ${BACKUP_DIR_TEMP}/meta/backup_gtid_executed.sql;\""
		elif [ $_firstSlave == $YES ];then
			echo "Read MySQL log file for the start binary log file and position for ${slavehost}"
			cmd='tac '${MYSQL_LOG_FILE}' | grep -m 1 "InnoDB: Last MySQL binlog file position" | awk '\'' {print $8 $11}'\'' | cut -d '\'','\'' -f1'
			echo $cmd
			echo "${SSH} ${USER}@${slavehost} \"${cmd}\""
			logpos=$(${SSH} ${USER}@${slavehost} "${cmd}")

			cmd='tac '${MYSQL_LOG_FILE}' | grep -m 1 "InnoDB: Last MySQL binlog file position" | awk '\'' {print $8 $11}'\'' | cut -d '\''/'\'' -f2'
			echo $cmd

			echo "${SSH} ${USER}@${slavehost} \"${cmd}\""
			logfile=$(${SSH} ${USER}@${slavehost} "${cmd}")
			echo "start logfile:logpos is $logfile:$logpos"

			echo "Change master log file and postion on slave ${slavehost} ? (y/n)?"
			if [ $INTERACTIVE -ne 0 ]; then read answer; else answer="Y"; fi
			if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
				echo "${SSH} ${USER}@${slavehost} \"mysql -u '${ROOT}' -p'xxxx' -e \"CHANGE MASTER TO MASTER_HOST='${master}',MASTER_PASSWORD='${REPLPW}',     MASTER_USER='${REPLUSER}', MASTER_LOG_FILE='${logfile}',MASTER_LOG_POS=${logpos};\"\""
				${SSH} ${USER}@${slavehost} "mysql -u '${ROOT}' -p'${pwd}' -e \"CHANGE MASTER TO MASTER_HOST='${master}',MASTER_PASSWORD='${REPLPW}',     MASTER_USER='${REPLUSER}', MASTER_LOG_FILE='${logfile}',MASTER_LOG_POS=${logpos};\""
			fi
			
		else
			echo "Change master log file and postion on slave ${slavehost} ? (y/n)?"
			if [ $INTERACTIVE -ne 0 ]; then read answer; else answer="Y"; fi
			if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
				echo "ssh ${USER}@${slavehost} \"mysql -u '${ROOT}' -p'xxxx' -e \"CHANGE MASTER TO MASTER_HOST='${master}',MASTER_PASSWORD='${REPLPW}',     MASTER_USER='${REPLUSER}', MASTER_LOG_FILE='mysql-bin.000001',MASTER_LOG_POS=0;\"\""
				ssh ${USER}@${slavehost} "mysql -u '${ROOT}' -p'${pwd}' -e \"CHANGE MASTER TO MASTER_HOST='${master}',MASTER_PASSWORD='$REPLPW}',     MASTER_USER='${REPLUSER}', MASTER_LOG_FILE='mysql-bin.000001',MASTER_LOG_POS=0;\""
			fi
			
		fi
        fi

        echo "Start slave on slave ${slavehost} ? (y/n)?"
        if [ $INTERACTIVE -ne 0 ]; then read answer; else answer="Y"; fi
        if [ "$answer" == "y" ] || [ "$answer" == "Y" ]; then
                #echo "${SSH} ${USER}@${slavehost} \"mysql -u ${ROOT} -p'${pwd}' -e \"start slave;\"\""
                #${SSH} ${USER}@${slavehost} "mysql -u ${ROOT} -p'${pwd}' -e \"start slave;\""
                startSlave "${master}" "$slavehost" "$pwd"
        fi
}

ifcontinue()
{
	if [ "$INTERACTIVE" -eq 1 ]; then
		echo -e "Continue (y/n)?"
		read answer
		if [ "$answer" == "y" ]; then
			return $YES
		else
			return $NO
		fi
	else
		return $YES
	fi

}

