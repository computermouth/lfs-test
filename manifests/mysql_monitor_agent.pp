# ========================================================================
# Module Name - hq_mysql
# ========================================================================
# $Id: mysql_monitor_agent.pp 70383 2018-07-26 16:45:46Z mchen $
# $HeadURL: http://svn.businesswire.com/svn/sysadmin/puppet/modules/hq_mysql/trunk/manifests/mysql_monitor_agent.pp $
# ========================================================================
class hq_mysql::mysql_monitor_agent {
  require mysql_utils
  include mysql_utils::tools::mysql_monitor_agent348  #enterprise monitor
}
