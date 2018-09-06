# ========================================================================
# Module Name - hq_mysql
# ========================================================================
# $Id:  $
# $HeadURL:  $
# ========================================================================
class hq_mysql::mysql_client_5635 {
  #  TEST 1 -  commented out for test purpose only #
  require hq_repositories::mainclass
  #  TEST 1 -  END

  require hq_mysql::mysql_server_5635

  package { 'MySQL-client-advanced':
    ensure => $::operatingsystemmajrelease?
    {
      '6' => '5.6.35-1.el6',
      '7' => '5.6.35-1.el7',
    }
  }
}
