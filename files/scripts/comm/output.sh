#!/bin/bash

s_PrintInfo()
{
	msg=$1
	echo -e -n "\033[32;1m$msg\033[0m"
}
s_PrintWarning()
{
	msg=$1
	echo -e -n "\033[31;1m$msg\033[0m"
}
s_PrintError()
{
	msg=$1
	#echo -e -n "\033[31;1m$msg\033[0m"
	echo -e -n "$msg"
}


s_emailOut()
{
	sender=$1
	if [ "$sender" = "" ]; then
		sender="mysqldba"
	fi 

	msg=$2
	receiver=$3

	if [ "$receiver" = "" ]; then
		receiver="min.chen@businesswire.com"
	fi
	
	echo "mailx -r ${sender} -s \"${msg}\" $receiver"
	#mailx -r $sender -s "${msg}" $receiver
}


#s_emailOut mysqldba "min.chen@businesswire.com"
