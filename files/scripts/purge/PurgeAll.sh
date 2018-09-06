#!/bin/bash

BASEDIR=~/scripts/purge
trap 'increment' 2

increment()
{
  echo "Caught SIGINT ..."
  echo "Okay, I'll quit ..."
  exit 1
}

if [ -f $HOME/mysql.env ];then
   . $HOME/mysql.env
fi

echo -e "MySQL Binary Log Purge. \n\n"
if [ "$1" == "" ] ; then
	echo "Usage: PurgeAll.sh mysql user dbaopt password"
	exit 0
fi

#These two settings can be overwriten by PurgyBinaryLog.sh
RUN_INTERACTIVE=0
DEBUG=1

s_getAnswer()
{
	if [ "$RUN_INTERACTIVE" -eq 1 ]; then
	 	read answer	
	fi
}

s_exitError()
{
	echo "The script is terminated due to error(s)."
	exit 1
}

#PROD
echo -e "PurgeBinaryLog.sh hq2mysql2.nyprod"
${BASEDIR}/PurgeBinaryLog.sh $1 hq2mysql2.nyprod.businesswire.com 
if [ "$?" -eq 1 ] ; then s_exitError ;fi

echo -e "PurgeBinaryLog.sh hq2mysql1.nyprod hq2mysql2.nyprod"
${BASEDIR}/PurgeBinaryLog.sh $1 hq2mysql1.nyprod.businesswire.com hq2mysql2.nyprod.businesswire.com
if [ "$?" -eq 1 ] ; then s_exitError ;fi

echo -e "PurgeBinaryLog.sh hq2mysql2.scprod hq2mysql1.nyprod"
${BASEDIR}/PurgeBinaryLog.sh $1 hq2mysql2.scprod.businesswire.com hq2mysql1.nyprod.businesswire.com
if [ "$?" -eq 1 ] ; then s_exitError ;fi

echo -e "PurgeBinaryLog.sh hq2mysql1.scprod hq2mysql2.scprod"
${BASEDIR}/PurgeBinaryLog.sh $1 hq2mysql1.scprod.businesswire.com hq2mysql2.scprod.businesswire.com
if [ "$?" -eq 1 ] ; then s_exitError ;fi

echo -e "\n\n\n PROD : HQ MySQL servers bin-log purge. Complete!!!\n\n"




#QA
#s_getAnswer
echo -e "\n\n\n  TEST : HQ MySQL servers bin-log purge ...\n\n"
s_getAnswer
echo -e "PurgeBinaryLog.sh hq2mysql2.nytest"
${BASEDIR}/PurgeBinaryLog.sh $1 hq2mysql2.nytest.businesswire.com 
if [ "$?" -eq 1 ] ; then s_exitError ;fi

echo -e "PurgeBinaryLog.sh hq2mysql1.nytest hq2mysql2.nytest"
${BASEDIR}/PurgeBinaryLog.sh $1 hq2mysql1.nytest.businesswire.com hq2mysql2.nytest.businesswire.com
if [ "$?" -eq 1 ] ; then s_exitError ;fi

echo -e "PurgeBinaryLog.sh hq2mysql2.sctest hq2mysql1.nytest"
${BASEDIR}/PurgeBinaryLog.sh $1 hq2mysql2.sctest.businesswire.com hq2mysql1.nytest.businesswire.com
if [ "$?" -eq 1 ] ; then s_exitError ;fi

echo -e "PurgeBinaryLog.sh hq2mysql1.sctest hq2mysql2.sctest"
${BASEDIR}/PurgeBinaryLog.sh $1 hq2mysql1.sctest.businesswire.com hq2mysql2.sctest.businesswire.com
if [ "$?" -eq 1 ] ; then s_exitError ;fi

echo -e "\n\n\n TEST : HQ MySQL servers bin-log purge. Complete!!!\n\n"
s_getAnswer


#INT
echo -e "PurgeBinaryLog.sh hq2mysql1.scint.businesswire.com"
${BASEDIR}/PurgeBinaryLog.sh $1 hq2mysql1.scint.businesswire.com 
if [ "$?" -eq 1 ] ; then s_exitError ;fi
echo -e "\n\n\n  INT : HQ MySQL servers bin-log purge. Complete!!!\n\n"

