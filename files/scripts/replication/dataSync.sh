. ../comm/dbFuncs.sh

DEBUG=0

s_Exit ()
{
	echo "The script is terminated."
}

echo ""
echo ""
echo "######################################################################"
echo "	dataSync.sh: re-sync data from master to slave"		
echo "  Note: "
echo " (1) This script doesn't setup replication between two servers.    "
echo "  Only data is copied to Slave from master."
echo " (2) Please make sure the replication parameters have been setup "
echo "  ready before running this script. 	"	
echo "######################################################################"
echo `date`
if [ $# -lt 2 ];then
	echo "!!!!!!ERROR:Main(): Please provide master host and its slave host name and run the script again."
	s_Exit
	exit
fi

MasterHost=$1
SlaveHost=$2

echo "###Info:Main():	Sychronize from $MasterHost - > $SlaveHost with mysqldump"
s_showSlaveStatus $SlaveHost
echo "	Stop slave on ${SlaveHost} (y/n)?"
read answer
if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
	s_stopSlave $SlaveHost
	s_showSlaveStatus $SlaveHost
fi

echo -e "\n\nInfo:Main():Copying data from ${MasterHost} to ${SlaveHost}? (y/n)?"
read answer
if [ "$answer" = "y" ] || [ "$answer" = "Y" ];then
	s_syncData $MasterHost $SlaveHost 0
fi

echo -e "\n\n"
echo -e "###Info:Main(): Starting slave on $SlaveHost...\n"
echo "	Start slave on ${SlaveHost} (y/n)?"
read answer
if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
	s_startSlave $SlaveHost
	s_showSlaveStatus $SlaveHost
fi
