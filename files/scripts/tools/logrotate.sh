
#!/usr/bin/ksh

export PATH=$PATH:/usr/contrib/bin
export LogDir=$1
export Days=$2
date=$(date '+%Y.%m.%d-%H:%M:%S')

# Log Directory
#LogDir=/home/p029052/tools/logs
ARCHIVE_DIR=/home/p029052/tools/logs/archive

#inuse=find $LogDir/*log* -mtime +2 -exec /usr/sbin/fuser -u {} \; #loglist='find *log* -mtime +2;'

if (( $# < 2 ))
then
        echo "Usage  log.rotate.sh DIRECTORYPATH DAYS  (ie log.rotate.sh /opt/esisupt/logs/hds/ar/logs 10)"
        exit 1
fi

for i in `find ${LogDir}/*.log* ${LogDir}/*.out* -mtime +${Days}`;do
        num=`/usr/sbin/fuser -u ${i} 2>/dev/null | awk '{print $1}' | wc -l`
        if [ ${num} -gt 0 ]
        then
                echo "-----COPYING, GZIP'ing and MOVING open file ${i} to ${i}.${date}-----"
                cp ${i} ${i}.${date} | gzip ${i}.${date} | mv $i.${date}.gz ${ARCHIVE_DIR}
                echo "-----zero out ${i}-----"
                >${i}
        else
        echo "gzip'ing and moving ${i} to ${ARCHIVE_DIR}"
        mv ${i} ${i}.${date}
        gzip ${i}.${date}
        mv ${i}.${date}*.gz ${ARCHIVE_DIR}
fi
done

for i in `find ${LogDir}/*.log* ${LogDir}/*.out* `;do
        num=`/usr/sbin/fuser -u ${i} 2>/dev/null | awk '{print $1}' | wc -l`
        if [ ${num} -gt 0 ]
        then
                echo "-----COPYING, GZIP'ing and MOVING open file ${i} to ${i}.${date}-----"
                cp ${i} ${i}.${date} | gzip ${i}.${date} | mv $i.${date}.gz ${ARCHIVE_DIR}
                echo "-----zero out ${i}-----"
                >${i}
fi
done
