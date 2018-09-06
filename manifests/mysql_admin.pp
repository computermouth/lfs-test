# ========================================================================
# Module Name - hq_mysql
# ========================================================================
# $Id: mysql_admin.pp 70562 2018-08-06 19:28:06Z mchen $
# $HeadURL: http://svn.businesswire.com/svn/sysadmin/puppet/modules/hq_mysql/trunk/manifests/mysql_admin.pp $
# ========================================================================
class hq_mysql::mysql_admin{
  require hq_users
  require hq_repositories::mainclass

  $mysqlhome='/home/mysql'
  $scriptsdir="${mysqlhome}/scripts"
  $clustername=$::hq_farmid
  $installlogfile="${scriptsdir}/install.log"
  package { 'sysbench':
    ensure => installed,
  }

  package { 'perl-Time-HiRes':
    ensure => installed,
  }

  #download file from SVN to mysql home directory
  file { "${mysqlhome}/scripts":
    ensure  => directory,
    alias   => 'scripts',
    owner   => 'mysql',
    group   => 'mysql',
    mode    => '0700',
    source  => 'puppet:///modules/hq_mysql/scripts',
    recurse => true,
  }

  file { 'install.sh':
    ensure  => file,
    alias   => 'InstallScript',
    owner   => 'mysql',
    group   => 'mysql',
    mode    => '0700',
    path    => "${scriptsdir}/install.sh",
    content => template ('hq_mysql/install_adminscripts.sh.erb'),
    require => File['scripts'],
  }

  # deploy the code, make configuration ready for HQ
  exec {'deployadminscripts':
    command   => "/bin/bash ${scriptsdir}/install.sh",
    user      => 'mysql',
    path      => '/bin:/usr/bin',
    subscribe =>  File['scripts'],
    creates   => $installlogfile,
    require   => File['InstallScript'],
    onlyif    => "test -d ${scriptsdir}/server-conf",
  }
}
