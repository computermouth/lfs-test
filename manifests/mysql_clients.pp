# ========================================================================
# Module Name - hq_mysql
# ========================================================================
# $Id: mysql_clients.pp 40648 2015-04-21 22:38:17Z jwade $
# $HeadURL: http://svn.businesswire.com/svn/sysadmin/puppet/modules/hq_mysql/trunk/manifests/mysql_clients.pp $
# ========================================================================
class hq_mysql::mysql_clients {
  require bw_repo::bw_repo_client

  package { 'MySQL-client-advanced':
    ensure   => installed,
  }
}
