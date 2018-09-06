#!/bin/bash

echo "sysben testing - CPU"
echo "sysben testing - CPU result"
sysbench --test=cpu --cpu-max-prime=20000 run

echo "sysben testing - fileio"
echo "cd /var/mysql"  #  testing /var/mysql
cd /var/mysql
sysbench --test=fileio --file-total-size=20G prepare
echo "sysben testing - FILEIO result"
sysbench --test=fileio --file-total-size=20G --file-test-mode=rndrw --init-rng=on --max-time=180 --max-requests=0 run
sysbench --test=fileio --file-total-size=20G cleanup

echo "sysben testing - oltp"
sysbench --test=oltp --db-driver=mysql --mysql-socket=/var/mysql/tmp/mysql.sock --oltp-table-size=1000000 --mysql-db=slaptest --mysql-user=loadtester --mysql-password=loadtester prepare
echo "sysben testing - oltp result"
sysbench --test=oltp --db-driver=mysql --mysql-socket=/var/mysql/tmp/mysql.sock --oltp-table-size=1000000 --mysql-db=slaptest --mysql-user=loadtester --mysql-password=loadtester --max-time=60 --max-requests=0 --num-threads=50 run
 
sysbench --test=oltp --db-driver=mysql --mysql-socket=/var/mysql/tmp/mysql.sock --oltp-table-size=1000000 --mysql-db=slaptest --mysql-user=loadtester --mysql-password=loadtester cleanup
