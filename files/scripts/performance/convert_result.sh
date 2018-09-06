#awk 'gsub(/.*:|.seconds*/,"")' $1 |  awk 'ORS=NR%5?" ":RS' | awk '{print $4,$4*$5,$1,$2,$3'}  >> $2 
awk 'gsub(/.*:|.seconds*|Using.*/,"")' $1 | sed '/^ $/d' |  awk 'ORS=NR%5?" ":RS' | awk '{print $4,$4*$5,$1,$2,$3'}  >> $2
#awk 'gsub(/.*:|.seconds*/,"")' $1 |  awk 'ORS=NR%5?" ":RS' | awk '{print $4,$4*$5,$1,$2,$3'}  >> $2
#cat $1 | grep "innodb" | awk -F ',' '{print $6, $6*$7,$3,$4,$5}'   > result.data
