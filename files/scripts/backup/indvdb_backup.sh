echo "Usage: indvdb_backup.sh hostname dbname"
echo "mysqldump -u backupuser  -pb@ckup0lny  -h ${1} --routines --single-transaction --master-data=2 ${2}> mysql-data_${1}_${2}.sql"
mysqldump -u backupuser  -pb@ckup0lny  -h ${1} --routines --single-transaction --master-data=2 ${2}> mysql-data_${1}_${2}.sql
