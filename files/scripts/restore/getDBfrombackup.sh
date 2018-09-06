#########################################################
#Name: getDBfrombackup					#
#	extract a given db from the mysqldump file	#
#Usage: getDBfrombackup mysqldumpfile dbname		#
#Date: 4/4/2011	   					#
#Author: Min Chen					#
#########################################################

sed -n '/^-- Current Database: `'$2'`/,/^-- Current Database: `/p' ${1} > db_${2}.sql

