# ========================================================================
# Module Name - hq_mysql
# ========================================================================
# $Id: $
# $HeadURL:$
# ========================================================================
class hq_mysql::mysql_server_5635 {
  #  TEST 1-  Commented out for test purpose
  require hq_packages::hq_mysql
  require hq_filesystem
  ###require hq_mysql::mysql_client_5635

  #This module depends on hq_filesystem::hqmysql and bw_packages::libaio
  # $hq_farmid="hq2mysql"
  #  TEST 1-  end # 


  if $::bw_location != '' {
    if $::bw_location == 'sf' {
      $code1=1
    }
    elsif $::bw_location == 'ny' {
      $code1=2
    }
    elsif $::bw_location == 'sc' {
      $code1=3
    }
    else {
      fail "Unrecognized bw_location ${::bw_location}"
    }
  }
  else {
    fail 'bw_location is not defined'
  }
  if $::bw_lifecycle != '' {
    case $::bw_lifecycle{
      'local': {$cycle=00}
      'lab': {$cycle=00}
      'dev': {$cycle=01}
      'int': {$cycle=02}
      'test': {$cycle=03}
      'prod': {$cycle=04}
      default: {fail "Unrecognized bw_lifecycle: ${::bw_lifecycle}"}
    }
  }
  else {
    fail 'bw_lifecycle is not defined'
  }

  $serverid="${code1}${cycle}${::hostname}"

  file { '/home/mysql/mysql.env':
    ensure => file,
    owner  => mysql,
    group  => mysql,
    mode   => '0700',
    source => 'puppet:///modules/hq_mysql/conf/mysql.env',
  }

  file { '/home/mysql/mysql_users.sh':
    ensure  => file,
    owner   => mysql,
    group   => mysql,
    mode    => '0700',
    content => template('hq_mysql/mysql_users.sh.erb'),
  }

  #Required to replace mysql-lib
  package { 'MySQL-shared-compat-advanced':
    ensure => $::operatingsystemmajrelease ?{
      '6' => '5.6.35-1.el6',
      '7' => '5.6.35-1.el7',
    }
  }

  #MySQL server is conflict with mysql-libs, this package need to be removed and replaced with MySQL-shared-compt ensured by hq_packages
  #  package { "mysql-libs": 
  #         ensure => absent, 
  #  }

  if !defined(Package['libaio'])
  {
    package {'libaio':
      ensure => 'installed'
    }
  }
  package { $::operatingsystemmajrelease ?{
    '6' => 'numactl',
    '7' => 'numactl-libs'}:
      ensure  => 'installed',
      alias   => 'numactl'
  }

  #MySQL server
  package { 'MySQL-server-advanced':
    ensure  => $::operatingsystemmajrelease ?{
      '6' => '5.6.35-1.el6',
      '7' => '5.6.35-1.el7',
    },
    require => [ #  TEST 2 - For local test purpose,commented out ###
      Package['mysql-libs'], #  TEST 2 - end ###
      File['/var/mysql/data'],
      Package['libaio'],
      Package['numactl']
    ],
  }

  #MySQL environment
  if defined(File['/var/mysql'])
  {
    realize File['/var/mysql']
  }
  else
  {
    file {  '/var/mysql':
      ensure => 'directory',
      alias  => 'BaseDir',
      owner  => 'mysql',
      group  => 'mysql',
      mode   => '0750',
    }
  }

  file {  '/var/mysql/data':
    ensure  => 'directory',
    alias   => 'DataDir',
    owner   => 'mysql',
    group   => 'mysql',
    mode    => '0750',
    require => File['/var/mysql'],
  }

  file {  '/var/mysql/backup':
    ensure  => 'directory',
    alias   => 'BackupDir',
    owner   => 'mysql',
    group   => 'mysql',
    mode    => '0750',
    require => File['/var/mysql'],
  }

  file { ['/var/mysql/tmp','/var/mysql/logs']:
    ensure => 'directory',
    owner  => 'mysql',
    group  => 'mysql',
    mode   => '0750',
  }

  #MySQL configuration file
  file { '/etc/my.cnf':
    ensure  => 'present',
    owner   => 'mysql',
    group   => 'mysql',
    mode    => '0600',
    content => template('hq_mysql/my.cnf.erb'),
    require => Package['MySQL-server-advanced'],
  }

  #MySQL local configuration file with the parameters related to localhost
  file { '/etc/my_local.cnf':
    ensure  => 'present',
    replace => 'no',
    owner   => 'mysql',
    group   => 'mysql',
    mode    => '0600',
    content => template('hq_mysql/my_local.cnf.erb'),
  }

  #Change MySQL data directory from default /var/lib/mysql to /var/mysql/data after installation when MySQL Server installation is refreshed
  exec {'ChangeDataDirectory':
    command     =>  'mv /var/lib/mysql/*  /var/mysql/data/; rm -r /var/lib/mysql',
    path        => '/bin/:/usr/bin',
    subscribe   => Package['MySQL-server-advanced'],
    require     => File['/var/mysql/data'],
    onlyif      => [
      'test -f /var/lib/mysql/mysql/user.frm',
      'test ! -f /var/mysql/data/mysql/user.frm',
      'test -d /var/mysql/data',
    ],
    refreshonly => true,
  }

  #Remove mysql service from auto start list=  service enable=>false will remove mysql from chkconfig on test and prod
  $enable = $::bw_lifecycle ? {
    /(test|prod)/ => false,
    default       => true,
  }

  $ensure = $::bw_lifecycle ? {
    /(dev|int|test|prod)/ => false,
    default               => true,
  }
  #start up mysql service after installation:
  service {'mysql':
    enable    => $enable,
    subscribe => Exec['ChangeDataDirectory'],
    require   => [
      Exec['ChangeDataDirectory'],
      File['/etc/my.cnf'],
      File['/etc/my_local.cnf'],
      Package['MySQL-server-advanced']
    ],
  }

  if $::bw_role == 'hq_mysql'
  {
    file { '/home/mysql/.mysql_history':
      ensure => link,
      owner  => 'mysql',
      group  => 'mysql',
      mode   => '0600',
      target => '/dev/null',
    }
  }
  exec {'startMySQL':
    command     => '/usr/bin/sudo /etc/init.d/mysql start',
    subscribe   => Exec['ChangeDataDirectory'],
    require     => [
      Exec['ChangeDataDirectory'],
      File['/etc/my.cnf'],
      File['/etc/my_local.cnf'],
    ],
    refreshonly => true,
  }
  #create mysql users
  exec {'create_users':
    command     => '/bin/bash /home/mysql/mysql_users.sh',
    path        => ['/bin','/sbin','/usr/bin','/usr/sbin'],
    require     => [
      Exec['startMySQL'],
      File['/home/mysql/mysql_users.sh'],
    ],
    refreshonly => true,
  }
}
