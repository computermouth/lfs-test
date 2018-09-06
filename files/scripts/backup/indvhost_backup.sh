echo "Usage: indvhost_backup.sh hostname "
echo "/usr/bin/mysqldump -u backupuser  -pb@ckup0lny  -h ${1} --routines --single-transaction --master-data=2 --all-databases> mysql-data_${1}_alldatabases.sql"
/usr/bin/mysqldump -u backupuser  -pb@ckup0lny  -h ${1} --routines --single-transaction --master-data=2 --all-databases> mysql-data_${1}_alldatabases.sql
