# ========================================================================
# Module Name - hq_mysql
# ========================================================================
# $Id: mysql_client_5620.pp 40648 2015-04-21 22:38:17Z jwade $
# $HeadURL: http://svn.businesswire.com/svn/sysadmin/puppet/modules/hq_mysql/trunk/manifests/mysql_client_5620.pp $
# ========================================================================
class hq_mysql::mysql_client_5620 {
  #  TEST 1 -  commented out for test purpose only #
  require hq_repositories::mainclass
  #  TEST 1 -  END

  require hq_mysql::mysql_server_5620

  package { 'MySQL-client-advanced':
    ensure   => '5.6.20-1.el6',
  }
}
