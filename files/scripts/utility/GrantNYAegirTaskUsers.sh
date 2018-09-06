#!/bin/bash
#Create NY users for task and aegir users
#This scirpt can be used on all HQ cluster and all tiers, but should only be enabled when NY node is available
# Min Chen - 8/31/2016


if [ -z ${BW_LIFECYCLE} ];then
	echo "BW_LIFECYCLE is not defined"
	exit
fi

if [ -f $HOME/mysql.env ]; then
	. $HOME/mysql.env
fi

hname=`hostname -s`
CLUSTERNAME="${hname:0:3}"

SCLOC="sc${BW_LIFECYCLE}"
NYLOC="ny${BW_LIFECYCLE}"
TASKHOST="${CLUSTERNAME}task1"
AEGIRHOST="${CLUSTERNAME}aegir1"
DOCHANGE=1
mysqluser="dbaopt"
datnum=`date +%Y%m%d-%H%M`


masterhost="${CLUSTERNAME}mysql1"
AEGIRUSER='aegir_dbuser'
TEMPDB='sodb'

#read -s -p "Enter MYSQL ${mysqluser} password for $"masterhost".${SCLOC}: " mysqlRootPassword
#while !  mysql -u ${mysqluser} -p$mysqlRootPassword -h ${masterhost}.${SCLOC} -e ";" ; do
#       read -p "Can't connect, please retry: " mysqlRootPassword
#done
#PWD=$mysqlRootPassword
PWD="Zu0Cr0N!"
mysqlserver="mysql -u ${mysqluser} -p${PWD} -h ${masterhost}.${SCLOC}.businesswire.com" 
echo "${mysqlserver/$PWD/xxx}"

main()
{

	checkUsers "${TASKHOST}" 
	checkUsers "${AEGIRHOST}"
}
#Find all Drupal users which have not been granted from the NY hosts. 
usersNotNYReady ()
{
   	myHOST=$1
	searchSQL="SELECT host,user FROM mysql.user WHERE host LIKE '${myHOST}.${SCLOC}%' AND user!='${AEGIRUSER}' AND user NOT IN (SELECT user FROM mysql.user WHERE host LIKE '${myHOST}.${NYLOC}%')" 
	echo "searchSQL is ${searchSQL}"
	${mysqlserver}  -e "${searchSQL};" | grep "${myHOST}.${SCLOC}" 
	return $?
}

#General SQL to create users from NY host 
# The SQL will do: 
# (1) Create a temporary table and load the data from mysql.user for users which need to add NY host
# (2) Update the host column to the NY host
# (3) Load the records in the temporary table into mysql.user to create the new users
createNewUserSQL ()
{
  myHOST=$1
  newuserSQL=$2
  
  newuserSQL="CREATE TABLE IF NOT EXISTS ${TEMPDB}.${myHOST}nyuser like mysql.user; TRUNCATE TABLE  ${TEMPDB}.${myHOST}nyuser;INSERT INTO ${TEMPDB}.${myHOST}nyuser (SELECT * FROM mysql.user WHERE host='${myHOST}.${SCLOC}.businesswire.com' AND user!='${AEGIRUSER}' AND user NOT IN (SELECT user FROM mysql.user WHERE host='${myHOST}.${NYLOC}.businesswire.com'));UPDATE ${TEMPDB}.${myHOST}nyuser SET host='${myHOST}.${NYLOC}.businesswire.com';INSERT INTO mysql.user ( SELECT * FROM ${TEMPDB}.${myHOST}nyuser); DROP TABLE ${TEMPDB}.${myHOST}nyuser;"
  return
}

#General SQL to grant DB privileges for new NY users.
# The SQL will do: 
# (1) Create a temporary table and load the data from mysql.db for users which need to add NY host
# (2) Update the host column to the NY host
# (3) Load the records in the temporary table into mysql.db to grant DB privileges to the newly
#     created users. 
createNewDBSQL ()
{
  myHOST=$1
  newdbSQL=$2
  newdbSQL="CREATE TABLE IF NOT EXISTS ${TEMPDB}.${myHOST}nydb like mysql.db;TRUNCATE TABLE  ${TEMPDB}.${myHOST}nydb; INSERT INTO ${TEMPDB}.${myHOST}nydb (SELECT * FROM mysql.db WHERE host='${myHOST}.${SCLOC}.businesswire.com' AND user!='${AEGIRUSER}' AND user NOT IN (SELECT user FROM mysql.db WHERE host ='${myHOST}.${NYLOC}.businesswire.com'));UPDATE ${TEMPDB}.${myHOST}nydb SET host='${myHOST}.${NYLOC}.businesswire.com'; INSERT INTO mysql.db (SELECT * FROM ${TEMPDB}.${myHOST}nydb);DROP TABLE ${TEMPDB}.${myHOST}nydb;"
  return
}

checkUsers()
{
	myHOST=$1
	
	echo "Searching DB users has been granted from ${myHOST}.${SCLOC} but not been granted from ${myHOST}.${NYLOC}..."

	usersNotNYReady "$myHOST"
	result=$?
	if [ $result -eq 0 ]; then
		echo "Found out the user(s) which has not been granted from ${myHOST}.${NYLOC}."

		
		#$mysqlserver -e "${sSQL};" | grep "task"  
		createNewUserSQL "$myHOST" $newuserSQL
		#echo "$newuserSQL"
	
		createNewDBSQL "$myHOST" $newdbSQL
		#echo "$newdbSQL"
		grantSQL="BEGIN;${newuserSQL};${newdbSQL};COMMIT;flush privileges;"
		echo "Running SQL: ${grantSQL}"
		echo -e "ALARM - Need to run the following SQL on mysql1.${SCLOC}: \n$sSQL"
		echo "${DOCHANGE}"
		if [ $DOCHANGE -eq 1 ];then
			echo "Create tempoary table for new user and db"
			echo "Backing up mysql.user table..."
			backupUserTable
			echo "Done"

			echo "Backing up mysql.db table..."
			backupDBTable
			echo "Done"

			echo "Doing the change...."
			executeSQL "${grantSQL}"
			ret=$?
			echo "Done"
		fi
	else
		echo "All users from ${myHOST}.sc${BW_LIFECYCLE} has privileges from ${myHOST}.ny${BW_LIFECYCLE}.No action is needed"
	fi

	echo "Verfiy if there is still users not granted from NY...."
	usersNotNYReady "$myHOST"
	result=$?
	if [ $result -eq 0 ]; then
		echo "Failed - still have users not granted from NY."
		echo "ALARM - Please check with the administrator"
	else
		echo "Succeed"
	fi
}
       
executeSQL()
{
	execSQL=$1
	#sSQL="select host from ${TEMPDB}.task1ny limit 1"
	result=1
	echo "executeSQL: $execSQL"
	${mysqlserver}  -e "${execSQL};" 
        result=$?	
	if [ $result -eq 0 ]; then
		echo "SUCCEED!"
	else
		echo "FAILED!"
	fi
	return $result
         
}

backupUserTable()
{
	sSQL="SELECT * FROM mysql.user"
  	${mysqlserver}  -e "${sSQL};" > $HOME/mysqluserbackup_${datnum}.sql
        result=$?
        if [ $result -eq 0 ]; then
                echo "SUCCEED!"
        else
                echo "FAILED!"
        fi
	return $result
}

backupDBTable()
{
	sSQL="SELECT * FROM mysql.db"
  	${mysqlserver}  -e "${sSQL};" > $HOME/mysqldbbackup_${datnum}.sql
        result=$?
        if [ $result -eq 0 ]; then
                echo "SUCCEED!"
        else
                echo "FAILED!"
        fi
	return $result
}
main
