#!/bin/bash
MyUSER="root"     # USERNAME
MyPASS="L@bHJ"       # PASSWORD
MyHOST="localhost"          # Hostname

MyOLDDB=$1
MyNEWDB=$2

# Linux bin paths, change this if it can not be autodetected via which command
MYSQL="$(which mysql)"


# Get data in dd-mm-yyyy format
NOW="$(date +"%d-%m-%Y")"

### Get all databases name ###
DBS="$($MYSQL -u $MyUSER -h $MyHOST -p$MyPASS -Bse 'show databases')"
FOUND=0
for db in $DBS
do [ "$db" = "$MyNEWDB" ] && FOUND=1
done

$FOUND && exit

TABLES=$($MYSQL -u $MyUSER -p$MyPASS -h $MyHOST $MyOLDDB -e 'show tables' | awk '{ print $1}' | grep -v '^Tables' )

echo "$MYSQL -u $MyUSER -p$MyPASS -h $MyHOST -e \"CREATE DATABASE $MyNEWDB\""
$MYSQL -u $MyUSER -p$MyPASS -h $MyHOST -e "CREATE DATABASE $MyNEWDB"

for t in $TABLES
do
        echo "Deleting $t table from $MDB database..."
        echo "$MYSQL -u $MyUSER -p$MyPASS -h $MyHOST $MyOLDDB -e \"RENAME TABLE ${MyOLDDB}.${t} to ${MyNEWDB}.${t}\""
        $MYSQL -u $MyUSER -p$MyPASS -h $MyHOST $MyOLDDB  -e "RENAME TABLE ${MyOLDDB}.${t} to ${MyNEWDB}.${t}"
done

