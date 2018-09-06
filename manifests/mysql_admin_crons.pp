class hq_mysql::mysql_admin_crons{
  require mysql_admin
  
  $mysqlhome='/home/mysql'
  $scriptsdir="${mysqlhome}/scripts"

#if $::bw_lifecycle == "dev" 
#{ 	
#	cron { backup:
#		command => "${SCRIPTSDIR}/backup/alldata_backup.sh 2>&1 | tee ${SCRIPTSDIR}/logs/dailybackup_drupal_today.log 2>&1;status=`grep 'ALARM' ${SCRIPTSDIR}/logs/dailybackup_drupal_today.log`;sub=\"MySQL Backup HQ2\"; [ -z \"\$status\" ] && msubject=\"OK -\"\${sub} || msubject=\"ALARM-\"\${sub}; echo \"Subject: \${msubject}\"  |  cat - ${SCRIPTSDIR}/logs/dailybackup_drupal_today.log | /usr/sbin/sendmail -f MySQLDBA_HQ2 mysql_dba@businesswire.com; cat ${SCRIPTSDIR}/logs/dailybackup_drupal_today.log >>${SCRIPTSDIR}/logs/dailybackup_drupal.log && rm ${SCRIPTSDIR}/logs/dailybackup_drupal_today.log" ,
#		user => mysql,
#		hour => 1,
#		minute => 0	  
#	}

#	cron { binlogpurge:
#		command => "${SCRIPTSDIR}/purge/PurgeAll.sh Zu0Cr0N! 2>&1 | tee ${SCRIPTSDIR}/logs/PurgeAll.log; status=`grep 'Error' ${SCRIPTSDIR}/logs/PurgeAll.log`;sub=\"HQ2 weekly binary log purge\"; [ -z \"\$status\" ] && msubject=\"OK -\"\${sub} || msubject=\"ALARM-\"\${sub}; echo \"Subject: \${msubject}\" | cat - ${SCRIPTSDIR}/logs/PurgeAll.log | /usr/sbin/sendmail -f MySQLDBA_HQ2 mysql_dba@businesswire.com" ,
#		user => mysql,
#		hour => 23,
#		minute => 45	  
#	}

#	cron { logrotate:
#		command => "${SCRIPTSDIR}/performance/queries/mysqllogrotate.sh 2>&1 | tee ${SCRIPTSDIR}/logs/mysqllogrotate.log;status=`grep 'ALARM' ${SCRIPTSDIR}/logs/mysqllogrotate.log`;sub=\"MySQL daily error slow log rotate HQ2\"; [ -z \"\$status\" ] && msubject=\"OK -\"\${sub} || msubject=\"ALARM-\"\${sub}; echo \"Subject: \${msubject}\" | cat - ${SCRIPTSDIR}/logs/mysqllogrotate.log | /usr/sbin/sendmail -f MySQLDBA_HQ2 mysql_dba@businesswire.com" ,
#		user => mysql,
#		hour => 5,
#		minute => 0	  
#	}
#}

}
