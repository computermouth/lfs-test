mysqldump -u $1 -p$2 --routines --single-transaction --all-databases | gzip -c > mysql-data.sql.gz

