#PurgeBinaryLog.sh MasterHostName [SlaveHostName1] [SlaveHostName2]...
./PurgeAll.sh dbaopt_password


##########Functionalities:
	(1) Check all slave status to make sure the slaves are running
	(2) Purge binary log files n days older by running PURGE LOG FILES. ( n=7)
	RUN_INTERACTIVE=1  running the script in interactive mode, user input (ENTER) is needed.
	RUN_INTERACTIVE=0  running the script silient mode, will termincated for any error messages. it is used for crontab.


##########Deployment: 
	(1) In theory, the script can be running on all MySQL servers
	(2) ~scripts/comm/monitor.sh is needed before running this script.
	(3) ~scripts/comm/output.sh is needed before running this script.
	(4) Need to define MYSQL_SVR_USER=dbbopt in PurgeBinaryLog.sh

