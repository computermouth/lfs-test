BACKUPFILE="mysql-data_DRUPAL_sfprodi7-z1_20101130-0010.sql"
RESTOREDB="ihsnewshqbusines"
RESTORETOTIME='2010-11-30 15:35:00'
#gunzip ${BACKUPFILE}.gz 
grep "MASTER_LOG_FILE='" ${BACKUPFILE} 
#find out the first log file and log pos"
./getDBfrombackup.sh ${BACKUPFILE} ${RESTOREDB} 
mysql -u root -p < db_${RESTOREDB}.sql
mysqlbinlog --start-position=106 --stop-date=${RESTORETOTIME} --database=${RESTOREDB} mysql-bin.000153 | mysql -u root -p

