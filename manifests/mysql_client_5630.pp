# ========================================================================
# Module Name - hq_mysql
# ========================================================================
# $Id:  $
# $HeadURL:  $
# ========================================================================
class hq_mysql::mysql_client_5630 {
  #  TEST 1 -  commented out for test purpose only #
  require hq_repositories::mainclass
  #  TEST 1 -  END

  require hq_mysql::mysql_server_5630

  package { 'MySQL-client-advanced':
    ensure => $::operatingsystemmajrelease?
    {
      6 => '5.6.30-1.el6',
      7 => '5.6.30-1.el7',
    }
  }
}
