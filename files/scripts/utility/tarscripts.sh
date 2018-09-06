cd $HOME

EXCFILE=$HOME/exludes.txt

echo "scripts/install.*" > $EXCFILE 
echo "scripts/performance/queries/reports/*" >> $EXCFILE 
echo "scripts/logs/*" >> $EXCFILE 
echo "scripts/utility/checksum/result/*" >> $EXCFILE 

tar -cvf $HOME/mysqladmin_scripts.tar  -X ${EXCFILE} scripts
#rm $EXCFILE


