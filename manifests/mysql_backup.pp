# ========================================================================
# Module Name - hq_mysql
# ========================================================================
# $Id: mysql_backup.pp 40648 2015-04-21 22:38:17Z jwade $
# $HeadURL: http://svn.businesswire.com/svn/sysadmin/puppet/modules/hq_mysql/trunk/manifests/mysql_backup.pp $
# ========================================================================
class hq_mysql::mysql_backup {
  require  hq_filesystem
  require hq_repositories::mainclass
  require bw_repo::bw_repo_client

  package { 'meb':
    ensure   => installed,
  }

  exec { 'Change the Owner of MySQL Enterprise Backup':
    command     => 'ln -sf /opt/mysql/meb-3.8 /opt/mysql/meb;chown -R  mysql:mysql /opt/mysql/meb*',
    creates     => '/opt/mysql/mebmysql',
    path        => '/bin/:/usr/bin',
    subscribe   => Package['meb'],
    onlyif      => [
      '/usr/bin/test -d /opt/mysql/meb-3.8',
      '/usr/bin/test `/usr/bin/stat -c %U /opt/mysql/meb* | grep -i mysql | wc -l ` -eq 0'
      ],
    refreshonly =>true,
  }
}
