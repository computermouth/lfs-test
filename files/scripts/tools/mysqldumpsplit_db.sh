#!/bin/bash
# Author: Fabian Becker <halfdan@xnorfz.de>
## Extracts a database of an sql dump
# usage: 
./grep-db.sh dump.sql dbname
line=`grep -n "CREATE DATABASE $2" $1 | cut -d ":" -f 1`
next=`sed 1,${line}d $1|grep -m 1 -n "CREATE DATABASE" |cut -d ":" -f 1`
end=$(($line + $next - 1))
sed -n ${line},${end}p $1