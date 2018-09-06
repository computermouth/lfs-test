#!/bin/bash

LOGFILE="slaptest.log"
DATAFILE="slap_result.data"
USERS=( "20" "50" "100" "200" "500" "1000" "1400")
QUERIES=( "4500" "45000" "450000" )

echo "Test begin:" `date` > $DATAFILE
echo " " > $LOGFILE
#echo "Test Summary:" >> $DATAFILE
#echo "Test command:" >> $DATAFILE
echo "   mysqlslap --create-schema=slaptest  --user=loadtester --password=loadtester --auto-generate-sql --number-char-cols=4 --number-int-cols=7 --engine=innodb --auto-generate-sql-add-autoincrement --auto-generate-sql-load-type=mix --auto-generate-sql-unique-query-number=1000 --number-of-queries=x --detach=5 --protocol=TCP --concurrency=x --iterations=5">> $DATAFILE


for i in "${USERS[@]}"
 do
        for j in "${QUERIES[@]}"
        do
                mysqlslap --create-schema=slaptest --user=loadtester --password=loadtester --auto-generate-sql --number-char-cols=4 --number-int-cols=7 --engine=innodb --auto-generate-sql-add-autoincrement --auto-generate-sql-load-type=mix --auto-generate-sql-unique-query-number=1000 --number-of-queries=${j} --detach=5 --protocol=TCP --concurrency=${i} --iterations=5  2>&1 |  tee -a $LOGFILE
              cat ${LOGFILE} | grep Error
              if [ $? -eq 0 ]; then
                echo "MySQL broke with users for running  queries." >> $LOGFILE
                break
              fi
        done
done

echo "Test end: " `date` >> $DATAFILE
echo " Users Queries# TimeTaken(AVG)s TimeTaken(MIN)s TimeTaken(MAX)s TimeTaken/Query(AVG)ms" >> $DATAFILE
./convert_result.sh $LOGFILE $DATAFILE

#echo "Test end: "`date`  >> $DATAFILE
echo "Test result file ${DATAFILE} is generated."
echo " "

echo " "
echo " "
cat $DATAFILE

