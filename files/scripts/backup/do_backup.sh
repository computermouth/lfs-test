#!/bin/bash

backup_hot()
{
	sshuser=$1
	hostname=$2
	mysql_user=$3
	mysql_password=$4
	backup_dir=$5
	mysqlbackupoptions=$6
	dbtype=$7
	backuptime=$8
	result=$SUCCEED

 	if [ "$sshuser" == "" ] || [ "$hostname" == "" ] || [ "$mysql_user" == "" ] || [ "$mysql_password" == "" ] || [ "$backup_dir" == "" ] || [ "$mysqlbackupoptions" == "" ]; then
		echo "[ERROR]backup_enterprise: invalid input variables: sshuser=$sshuser hostname=$hostname mysqluser=${mysql_user} mysqlpass=xxxx backup dir = ${backup_dir}  mysqlbackupoptions=${mysqlbackupoptions}"
		result=$FAILED 
	else
		echo "${SSH} ${sshuser}@${hostname} \". ~/mysql.env; ${MYSQLBACKUP_SCHEDULE} mysqlbackup -u ${mysql_user} -pxxxx ${mysqlbackupoptions} --backup-dir=${backup_dir} --backup-image=${backup_dir}${hostname}_${dbtype}_${backuptime}.img.gz backup-to-image\""
		cmd=". ~/mysql.env; ${MYSQLBACKUP_SCHEDULE} mysqlbackup -u ${mysql_user} -p'${mysql_password}' ${mysqlbackupoptions}  --backup-dir=${backup_dir}  --backup-image=${backup_dir}${hostname}_${dbtype}_${backuptime}.img.gz backup-to-image"
		#${SSH} ${sshuser}@${hostname} ". ~/mysql.env; ${MYSQLBACKUP_SCHEDULE} mysqlbackup -u ${mysql_user} -p'${mysql_password}' ${mysqlbackupoptions}  --backup-dir=${backup_dir}  --backup-image=${backup_dir}${hostname}_${dbtype}_${backuptime}.img.gz backup-to-image"  | tail -n 5 | grep -i "mysqlbackup completed OK!"
		output=$(${SSH} ${sshuser}@${hostname} "$cmd" 2>&1)
		echo "${output}" | tail -n 5 | grep -i "mysqlbackup completed OK!"
		result=$?
	fi
	return $result 
}

backup_dump()
{
	hostuser=$1
	hostname=$2
	mysql_user=$3
	mysql_password=$4
	backup_dir=$5
	dbtype=$6
	backuptime=$7
	dumpoptions=$8

 	if [ "$hostuser" == "" ] || [ "$hostname" == "" ] || [ "$mysql_user" == "" ] || [ "mysql_password" == "" ] || [ "$backup_dir" == "" ] || [ "$dbtype" == "" ] || [ "$backuptime" == "" ]; then
		echo "[ERROR]backup_mysqldump: invalid input variables: $@"
		return 0 
	else
  		echo "${SSH} ${hostname} \". ~/mysql.env; ${MYSQLDUMP_CMD} -u ${mysql_user} -pxxx  ${dumpoptions} | gzip -c > ${backup_dir}mysql-data_${dbtype}_${hostname}_${backuptime}.sql.gz\""
       	${SSH} ${hostname} ". ~/mysql.env; ${MYSQLDUMP_CMD} -u ${mysql_user} -p${mysql_password}   ${dumpoptions} | gzip -c > ${backup_dir}mysql-data_${dbtype}_${hostname}_${backuptime}.sql.gz;ls -l ${backup_dir}mysql-data_${dbtype}_${hostname}_${backuptime}.sql.gz"
		return $? 
	fi


}
backup_binlog()
{
	sshuser=$1
	hostname=$2
	dbtype=$3
	datadir=$4
	backupdir=$5
	datenum=$6

	echo `date`
	echo "Backing up $dbtype bin logs from $hostname..."
	echo "${SSH} ${sshuser}@${hostname} \"${TAR_CMD} cvfp - ${datadir}mysql-bin.* | gzip -> ${backupdir}mysql-bin_${dbtype}_${hostname}_${datenum}.tar.gz\""
	${SSH} ${sshuser}@${hostname} "${TAR_CMD} cvfp - ${datadir}mysql-bin.* | gzip -> ${backupdir}mysql-bin_${dbtype}_${hostname}_${datenum}.tar.gz"

	echo "Done!"
	echo `date`
}

cleanup_hot()
{
	sshuser=$1
	hostname=$2
	retention=$3
	backupdir=$4
        
 	if [ "$hostname" == "" ] || [ "$retention" == "" ] || [ "$backupdir" == "" ] || [ "$sshuser" == "" ] ; then
		echo "[ERROR]cleanup_host: invalid input variables: $_"
		return $FAILED
	else
		echo "${SSH} ${sshuser}@${hostname} \"/usr/bin/find ${backupdir}* -mtime +${retention} -exec rm -r {} \\;\""
		${SSH} ${sshuser}@${hostname} "/usr/bin/find ${backupdir}* -mtime +${retention} -exec rm -r {} \\;"
		echo "${SSH} ${sshuser}@${hostname} \"/usr/bin/find ${backupdir}* -mtime +${retention} -exec rm  {} \\;\""
       	${SSH} ${sshuser}@${hostname} "/usr/bin/find ${backupdir}* -mtime +${retention} -exec rm  {} \\;"
		result=$?
		echo -e "Clean up is complete\n"
		
		return $result
		
	fi

}

cleanup_dump()
{
	sshuser=$1
	hostname=$2
	backupdir=$3
	retention=$4

 	if [ "$hostname" == "" ] || [ "$retention" == "" ] || [ "$backupdir" == "" ] || [ "$sshuser" == "" ] ; then
		echo "[ERROR]cleanup_dump: invalid input variables: $_"
		return $FAILED 
	else
		echo "Remove backup created ${retention} days before on ${hostname}..."
		echo "${SSH} ${hostname} \"find ${backupdir}* -mtime +${retention} -exec rm {} \\\\;\""
		${SSH} ${hostname} "find ${backupdir}/*  -mtime +${retention} -exec rm {} \\;"
		echo "${SSH} ${sshuser}@${hostname} \"/usr/bin/find ${backupdir}* -mtime +${retention} -exec rm -r {} \\;\""
		${SSH} ${sshuser}@${hostname} "/usr/bin/find ${backupdir}* -mtime +${retention} -exec rm -r {} \\;"
		result=$?
		echo -e "Clean up is complete\n"
		return $result
	fi
}
cleanup_binlog()
{
	sshuser=$1
	hostname=$2
	backupdir=$3
	retention=$4

	cleanup_dump $sshuser $hostname $backupdir $retention 

}

# Check if the backup disk has enought space for a new backup file
hasSpace()
{
    sshuser=$1
    hostname=$2
    diskvolumn=$3
    backupdir=$4

    #don't check for dev since dev may not have same disk volumn
    if [[ "$hostname" == *dev* ]];then
		return 1
    fi		 

    echo "Checking the available space on $diskvolumn"
    #if [ $OS == "UBUNTU" ] || [ $OS == "REDHAT" ]; then
    #	cmdSpace="/bin/df -k  | grep \"${diskvolumn}\" | awk '{print \$4}'"
    #else
    #	cmdSpace="/bin/df -k  | grep \"${diskvolumn}\" | awk '{print \$3}'"
    #fi
	# Use df -P to make all OS return the POSIX output format
	cmdSpace="/bin/df -k -P | grep \"${diskvolumn}\" | awk '{print \$4}'"
    diskspace=`${SSH} ${hostname} "${cmdSpace}"`
    #diskspace=$(${SSH} ${hostname} \"$cmdSpace\")
    #echo ${diskspace}
    echo "The data backup filesystem still has ${diskspace}K available."
    cmdNeed="ls -ltr ${backupdir}*.gz --block-size=1k  | tail -1 | awk '{print \$5}'"
    #echo  ${SSH} ${hostname} ${cmdNeed}
    spaceneed=`${SSH} ${hostname} "$cmdNeed"`
	if [ -z $spaceneed ]; then
		spaceneed="0"
    fi
    echo "The last backup need ${spaceneed}K space."
    if [ "$diskspace" -gt "$spaceneed" ]; then
         echo "Disk has enough space ($diskspace) for another backup ($spaceneed)."
         return 1
    else
         echo "ALARM!!! - Disk does not have enough space ($diskspace) for another backup ($spaceneed)."
         return 0 
    fi
}

backupSize()
{
   backupdir=$1
  
   return $(ls -ltr ${backupdir} --block-size=1k  | tail -1 | awk '{print $5}')

}

check_result ()
{
	result=$1
	echo "result is ${result}"
	if [ "$result" -eq "$SUCCEED" ]; then
		echo -e "${GREEN}SUCCEED${NORMAL}\n"
	else
    	echo -e "${RED}FAILED!!!${NORMAL}\n"
	    echo -e "ALARM!!! - The script is terminated. Please fix the problem and run this script again.\n"
	fi
	return $result
}
