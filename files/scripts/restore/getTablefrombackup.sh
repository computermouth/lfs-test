#########################################################
#Name: getDBfrombackup                                  #
#       extract a given db from the mysqldump file      #
#Usage: getDBfrombackup mysqldumpfile dbname            #
#Date: 4/4/2011                                         #
#Author: Min Chen                                       #
#########################################################

sed -n '/^-- Table structure for table `'$2'`/,/^-- Table structure for table `/p' ${1} > table_${2}.sql

