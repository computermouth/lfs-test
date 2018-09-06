# ========================================================================
# HQ MySQL Server
# ========================================================================
# $Id: init.pp 70562 2018-08-06 19:28:06Z mchen $
# $HeadURL: http://svn.businesswire.com/svn/sysadmin/puppet/modules/hq_mysql/trunk/manifests/init.pp $
# ========================================================================
class hq_mysql {
    case $::bw_role {
    'hq_mysql': {
      if $::hostname =~ /.mysql./
      {
        include hq_mysql::mysql_backup
        include hq_mysql::mysql_monitor_agent
        include hq_mysql::mysql_admin
        include hq_mysql::mysql_sshkey_public
        include hq_mysql::mysql_server_5635
        include hq_mysql::mysql_client_5635
      }
      else
      {
        include hq_mysql::mysql_clients
      }
    }
    'hq_workstation': {
      include mysql_server
      include mysql_clients
    }
    default: {}
  }
}

