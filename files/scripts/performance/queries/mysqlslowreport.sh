#!/bin/bash

if [ -f $HOME/mysql.env ];then
	. $HOME/mysql.env
fi

datenum=`date +%Y%m%d`
dofm=`date +%d`
echo $dofm
SCP_CMD=`which scp`
REPORT_RETENTION=30  #keep 30 days slow report. Slow repors is generated once per week, so total around 4 slow report will be kept after purge
SCP="${SCP_CMD} -i ${HOME}/.ssh/mysqldba_hq_dsa"
mysqldumpslowcmd=`which mysqldumpslow`

if [ $dofm -gt 7 ];then
	exit;
fi
 
archiveDir=/var/mysql/logs/archive
tempDir=~/scripts/performance/queries/reports
hostname=$1
[ ! -d ${tempDir} ] && mkdir ${tempDir} && echo "Directory ${tempDir} is created!"

echo "Clean up the directory for files ${REPORT_RETENTION} days(1 year) only..."
find ${tempDir}/. -name "${hostname}_slow*" -mtime +${REPORT_RETENTION} -exec ls {} \;
echo "Done!"

if [ "$hostname" == "" ]; then
	hostname="mysql1.sfprod"
fi

echo "Check if ${tempDir}/${hostname}_slow_query.log.${datenum} exists" 
if [ ! -f ${tempDir}/${hostname}_slow_query.log.${datenum} ];
then 
	echo "No,copy the file from mysql@${hostname}:${archiveDir}\/slow_query.log.${datenum}* to ${tempDir}\/${hostname}_slow_query.log.${datenum}"
	${SCP} mysql@${hostname}:${archiveDir}/slow_query.log.${datenum}* ${tempDir}/${hostname}_slow_query.log.${datenum}
	echo "Done!"
else
	echo "Yes!"
fi

echo "Sort by Average Time..."
if [ ! -f ${tempDir}/${hostname}_slowbyaveragetime.${datenum} ];then
	echo "${hostname} -- ${datenum}" >  ${tempDir}/${hostname}_slowbyaveragetime.${datenum} 
	echo "##################    Sorted by Average Time ########################" >> ${tempDir}/${hostname}_slowbyaveragetime.${datenum} 
	${mysqldumpslowcmd} -s at -t 10 ${tempDir}/${hostname}_slow_query.log.${datenum}>> ${tempDir}/${hostname}_slowbyaveragetime.${datenum}
fi

echo "Sort by Total Time..."
if [ ! -f ${tempDir}/${hostname}_slowbytotaltime.${datenum} ];then
	echo "${hostname} -- ${datenum}" >  ${tempDir}/${hostname}_slowbytotaltime.${datenum} 
	echo "##################    Sorted by Total Time ########################" >> ${tempDir}/${hostname}_slowbytotaltime.${datenum} 
	${mysqldumpslowcmd} -s t -t 10 ${tempDir}/${hostname}_slow_query.log.${datenum}>> ${tempDir}/${hostname}_slowbytotaltime.${datenum}
fi

echo "Sort by Count..."
if [ ! -f ${tempDir}/${hostname}_slowbycount.${datenum} ];then
	echo "${hostname} -- ${datenum}" >  ${tempDir}/${hostname}_slowbycount.${datenum} 
	echo "##################    Sorted by Count ########################" >> ${tempDir}/${hostname}_slowbycount.${datenum} 
	mysqldumpslow -s c -t 10 ${tempDir}/${hostname}_slow_query.log.${datenum}>> ${tempDir}/${hostname}_slowbycount.${datenum}
fi 

echo "All report have been generated!"
echo "Please check the files ${tempDir}/${hostname}_slowby*.${datenum} for query reports"

recp=mysql_dba@businesswire.com

echo "Email reports out..."
#(uuencode ${tempDir}/${hostname}_slowbyaveragetime.${datenum}  ${hostname}_slowbyaveragetime.${datenum}.txt;uuencode ${tempDir}/${hostname}_slowbytotaltime.${datenum}  ${hostname}_slowbytotaltime.${datenum}.txt;uuencode ${tempDir}/${hostname}_slowbycount.${datenum}  ${hostname}_slowbycount.${datenum}.txt; echo -e "Here are slow query reports on ${hostname} generated on ${datenum}, please review." ) | mailx -s "Slow Query Report on ${hostname} for ${datenum}" -r MySQLDBA_HQ mysql_dba@businesswire.com min.chen@businesswire.com 

echo -e "Subject: Slow Query Report from ${hostname} on ${datenum} \n\n Here are slow query reports on ${hostname} generated on ${datenum}, please review.\n\n $(cat ${tempDir}/${hostname}_slowbyaveragetime.${datenum}   ${tempDir}/${hostname}_slowbytotaltime.${datenum} ${tempDir}/${hostname}_slowbycount.${datenum})"| sendmail -f MySQLDBA_HQ2 ${recp} 
echo "Email complete!"
