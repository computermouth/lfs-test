#!/bin/bash


CMD_LOADBALANCER="sudo /sbin/service block-loadbalancer "
####Load configuration file and HA functions
if [ -f inc/MySQL_HA.sh ]; then
     . inc/MySQL_HA.sh
else
     echo "MySQL_HA.sh does not exist."
     exit
fi


###########################################################
#    Function:  enableServiceonhost                       #
#          enable MySQL service on the given host         #
#    Parameters:                                          #
#          $1:$host hostname                              #
#          $2:$servicename   mysql servicename            #
#  Reference to the following variables in conf:          #
#          N/A                                            #
#  Call functions:                                        #
#          runcmdonhost $host $cmd                        #
###########################################################
enableServiceonhost()
{
    host=$1
    servicename=$2
    cmd="${CMD_LOADBALANCER}"" stop"
    runcmdonhost "${host}" "${cmd}"

    echo "Wait ${SERVICE_NAME} up...."
    count=0
    while [ "$count" -lt 6 ]
    do
	isServiceup $host $servicename
   	ret=$?
        if [ "$ret" -eq "$NO" ]; then
               echo "   not yet, wait another 20 seconds..."
               sleep 20
               count=`expr $count + 1 `
         else
                break;
         fi
    done

   if [ $ret -eq $YES ]; then
         echo -e "${GREEN}Yes, ${SERVICE_NAME} is up."
	 return $OK
   else
         echo -e "${RED}No, ${SERVICE_NAME} is still down.${NORMAL}"
	 return $FAILED
   fi


}

###########################################################
#    Function:  disableService                            #
#          disable MySQL service on all host              #
#    Parameters:                                          #
#          $1:$host hostname                              #
#          $2:$servicename   mysql servicename            #
#  Reference to the following variables in conf:          #
#          N/A                                            #
#  Call functions:                                        #
#          runcmdonhost $host $cmd                        #
###########################################################

disableService()
{
        servicename=$2
	declare -a hosts=("${!1}")

        echo "Disable MySQL server ${SERVICE_NAME} on all MySQL hosts"
	for i in ${hosts[@]}
	do
               	disableServiceonhost $i $servicename 0 
	done

       echo "Wait ${SERVICE_NAME} down...."
       count=0
       while [ "$count" -lt 6 ]
       do
                isServiceenabled $SERVICE_NAME
                ret=$?
                if [ "$ret" -eq "$YES" ] ; then
                        echo "   not yet, wait another 20 seconds..."
                        sleep 20
                        count=`expr $count + 1 `
                else
                        break;
                fi
        done

        if [ "$ret" -eq "$NO" ]; then
                echo -e "${GREEN}Yes, ${SERVICE_NAME} is down.${NORMAL}"
		result=$OK
        else
                echo -e "${RED}No, ${SERVICE_NAME} is still up, call for help...${NORMAL}"
		result=$FAILED
        fi
	return $result
}

###########################################################
#    Function:  disableServiceonhost                      #
#          disable MySQL service on the given host        #
#    Parameters:                                          #
#          $1:$host hostname                              #
#          $2:$servicename   mysql servicename            #
#  Reference to the following variables in conf:          #
#          N/A                                            #
#  Call functions:                                        #
#          runcmdonhost $host $cmd                        #
#  Return:   $OK                                          #
#            $FAILED                                      #
###########################################################
disableServiceonhost()
{
    host=$1
    servicename=$2
    needverify=$3

    cmd="${CMD_LOADBALANCER}"" start"
    runcmdonhost "${host}" "${cmd}"

    if [ "$needverify" == "1" ]; then
    	isServiceup $host $servicename
    	ret=$?
    	if [ $ret -eq $YES ];then
		return $FAILED
    	else
		return $OK
    	fi
    else
	return $OK
    fi
}

###########################################################
#    Function:  isServiceup                               #
#          check if mysql service is up with right host IP#
#    Parameters:                                          #
#          $1:$host hostname                              #
#          $2:$servicename   mysql servicename            #
#  Reference to the following variables in conf:          #
#          N/A                                            #
#  Call functions:                                        #
#          N/A                                            #
###########################################################

isServiceup()
{
     host=$1
     servicename=$2
     

     lookupservice="nslookup "$servicename 
     lookuphost="nslookup "$host

      #get the ip address of the master host
     echo "   run: ${lookuphost} | grep \"Address:\" | grep -v \"#\""
     r1=`${lookuphost} | grep "Address:" | grep -v "#"` 
     echo "   Master host  = ${r1} "

      #get the ip address of the service
     echo "   run: ${lookupservice} | grep \"Address:\" | grep -v \"#\"" 
     #r2=`${lookupservice} | sed -n 6p` 
     r2=`${lookupservice} | grep "Address:" | grep -v "#"` 
     echo "   IP address of service = ${r2}"

  		
     #this r3 return has not been tested yet
     echo "   run: ${lookupservice} | sed -n 7p"
     r3=`${lookupservice} | sed -n 7p` 
     echo "   Second IP address of MySQL service  = ${r3} should be empty"

     if [ "$r1" == "$r2" ] && [ "$r3" == "" ]; then
         #echo "  OK! IP address of  ${servicename} provider equals to the IP address of the master ${host} and only one IP address is available for this service."
	 result=$YES         
     else
	if [ "$r3" == "" ] && [ "$r2" == "" ];then
		echo "Service ${servicename} is not active."
         #echo "   !!!Failed:IP address of MySQL service does not equal to the IP address of the Master or there are multiple IP addresses for MySQL service."
	else
		echo "FAILED: nslookup ${servicename} doesn't return a correct state, please manually check by running nslookup ${servicename} again."
	fi
	result=$NO         
     fi

   return $result
}

###########################################################
#    Function:  isServiceenabled                          #
#          check if mysql service is up                   #
#    Parameters:                                          #
#          $1:$servicename   mysql servicename            #
#  Reference to the following variables in conf:          #
#          N/A                                            #
#  Call functions:                                        #
#          N/A                                            #
#  return:   $YES|$NO                                     #
###########################################################

isServiceenabled()
{
    servicename=$1
    lookupservice="nslookup "$servicename
    echo "   Run: ${lookupservice} "
    ${lookupservice} | grep " server can't find ${servicename}" 
    ret=$?
    if [ $ret -eq 0 ];then
	return $NO
    else
	return $YES
    fi
} 
#enableServiceonhost hq2mysql1.sfprod.businesswire.com hq2mysql.businesswire.com
#disableServiceonhost hq2mysql1.sfprod.businesswire.com hq2mysql.businesswire.com
#isServiceup hq2mysql1.sfprod.businesswire.com  hq2mysql.businesswire.com
