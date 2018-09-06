#!/bin/bash


# Need ROOT defined 
if [ -f inc/MySQL_HA.conf ]; then
	. inc/MySQL_HA.conf
else
	echo "Can't load MySQL_HQ.conf."
        exit
fi

###########################################################
#    Function:  startMySQLMonitor                         #
#          Start MySQL Monitor agent on given host        #
#    Parameters:                                          #
#          $1:$host hostname                              #
#  Reference to the following variables in conf:          #
#          N/A                                            #
#  Call functions:                                        #
#          runcmdonhost "${host}" "${cmd}"                #
#          verifyResult "$host" "$vcmd" "$str"            #
###########################################################
startMySQLMonitor()
{
        host=$1

        echo `date`"Start slave ${host} MySQL ..."
        cmd="sudo /etc/init.d/mysql-monitor-agent start"
        runcmdonhost "${host}" "${cmd}"
	vcmd="sudo /etc/init.d/mysql-monitor-agent status"
	str="running"
	verifyResult "$host" "$vcmd" "$str"
	ret=$?
	return $ret

}

###########################################################
#    Function:  stopMySQLMonitor                          #
#          Stop MySQL Monitor agent on given host         #
#    Parameters:                                          #
#          $1:$host hostname                              #
#   Reference to the following variables in conf:         #
#          N/A                                            #
#   Call functions:                                       #
#          runcmdonhost "${host}" "${cmd}"                #
#          verifyResult "$host" "$vcmd" "$str"            #
###########################################################
stopMySQLMonitor()
{
        host=$1
        echo `date` "Shutdown mysql monitor on ${host} ...."
        cmd="sudo /etc/init.d/mysql-monitor-agent stop"
        runcmdonhost "${host}" "${cmd}"

        vcmd="sudo /etc/init.d/mysql-monitor-agent status"
        str="running"
        verifyResult "$host" "$vcmd" "$str"
        ret=$?
        echo `date` "Shutdown mysql monitor on ${host} complete"
        return $ret
}


###########################################################
#    Function:  saveEMId                                  #
#          backup mysql.inventory to local disk           #
#    Parameters:                                          #
#          $1:$host hostname                              #
#          $2:$pwd  mysql system user password            #
#          $3#:$backup_dir  backup location               #
#   Reference to the following variables in conf:         #
#          ${ROOT} :mysql system user name                #
#   Call functions:                                       #
#          runcmdonhost "${host}" "${cmd}"                #
#          verifyResult "$host" "$vcmd" "$str"            #
###########################################################
saveEMId()
{
  host=$1
  pwd=$2
  backup_dir=$3

  sSQL="SELECT name,value INTO OUTFILE '${backup_dir}/${host}Id.txt' FIELDS TERMINATED BY ',' LINES TERMINATED BY '\n' from mysql.inventory;"
  cmd="mysql -u ${ROOT} -p'${pwd}' -h${host} -e \"${sSQL}\""
  
  runcmdonhost "localhost" "$cmd"
  vcmd="ls -l ${backup_dir}"
  lookstr="${host}Id.txt"
  verifyResult "$host" "$vcmd" "$str" 
  ret=$?
  return $ret	
}

###########################################################
#    Function:  loadEMId                              #
#          restore mysql.inventory from local disk        #
#    Parameters:                                          #
#          $1:$host hostname                              #
#          $2:$pwd  mysql system user password            #
#          $3:$backup_dir backup location                 #
#   Reference to the following variables in conf:         #
#          ${ROOT} :mysql system user name                #
#   Call functions:                                       #
#          runcmdonhost "${host}" "${cmd}"                #
#          verifyResult "$host" "$vcmd" "$str"            #
###########################################################
loadEMId()
{
   host=$1
   pwd=$2
   backup_dir=$3
  sSQL="SET @@SESSION.SQL_LOG_BIN=0;LOAD DATA INFILE '${backup_dir}/${host}Id.txt' REPLACE INTO TABLE mysql.inventory FIELDS TERMINATED BY ',' LINES TERMINATED BY '\n';"
  cmd="mysql -u ${ROOT} -p'${pwd}' -h ${host} -e \"${sSQL}\""
  runcmdonhost "localhost" "$cmd"
}


###########################################################
#    Function:  restore_EMId                              #
#          bounce mysql monitor agent to make new EMId    #
#                effective                                #
#    Parameters:                                          #
#          $1:$host hostname                              #
#          $2:$pwd  mysql system user password            #
#          $3:$backup_dir   backup location               #
#   Reference to the following variables in conf:         #
#         N/A                                             #
#   Call functions:                                       #
#          loadEMId "${host}" "${cmd}"  "${backup_dir}    #
#          stopMySQLMonitor "$host"                       #
#          startMySQLMonitor "$host"                      #
###########################################################
restore_EMId()
{
        host=$1
        pw=$2
        backup_dir=$3
        loadEMId "${host}" "${pw}" "${backup_dir}"
        echo "Bounce mysql monitor on ${host} ..."
        stopMySQLMonitor "$host"
        startMySQLMonitor "$host"
        echo "Bounce mysql monitor on ${host} - complete."
}
