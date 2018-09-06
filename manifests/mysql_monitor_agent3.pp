# ========================================================================
# Module Name - hq_mysql
# ========================================================================
# $Id: mysql_monitor_agent3.pp 40648 2015-04-21 22:38:17Z jwade $
# $HeadURL: http://svn.businesswire.com/svn/sysadmin/puppet/modules/hq_mysql/trunk/manifests/mysql_monitor_agent3.pp $
# ========================================================================
# Install MySQL Enterprise Monitor Agent 3
class hq_mysql::mysql_monitor_agent3 {
  require hq_filesystem
  require hq_repositories::mainclass

  file { '/usr/local/pkgs/mysqlmonitoragent-3.0.12.3016-linux-x86-64bit-installer.bin':
    ensure => file,
    alias  => 'Agent3Pkg',
    owner  => root,
    group  => root,
    mode   => '0777',
    source => 'puppet:///modules/hq_mysql/pkgs/EM/mysqlmonitoragent-3.0.12.3016-linux-x86-64bit-installer.bin',
  }

  file { '/usr/local/pkgs/mysqlmonitoragent-3.0.12.3016-linux-x86-64bit-update-installer.bin':
    ensure => file,
    alias  => 'Agent3UpdatePkg',
    owner  => root,
    group  => root,
    mode   => '0777',
    source => 'puppet:///modules/hq_mysql/pkgs/EM/mysqlmonitoragent-3.0.12.3016-linux-x86-64bit-update-installer.bin',
  }

  file { '/usr/local/pkgs/agent3.conf':
    ensure  => file,
    alias   => 'Agent3Config',
    owner   => root,
    group   => root,
    mode    => '0777',
    content => template('hq_mysql/pkgs/EM/agent3.conf.erb'),
  #source => "puppet:///modules/hq_mysql/pkgs/EM/agent3.conf",
  }

  exec {'Install MySQL Enterprise Monitor Agent3':
    alias     => 'Agent3Installed',
    cwd       => '/usr/local/pkgs',
    command   =>  '/usr/local/pkgs/mysqlmonitoragent-3.0.12.3016-linux-x86-64bit-installer.bin --optionfile /usr/local/pkgs/agent3.conf  --mode unattended',
    path      => '/bin/:/usr/bin',
    user      => 'mysql',
    creates   => '/opt/mysql/enterprise/agent3',
    require   => File['Agent3Pkg'],
    logoutput => true,
  }

  exec {'Update MySQL Enterprise Monitor Agent3':
    alias       => 'Agent3Updated',
    cwd         => '/usr/local/pkgs',
    command     =>  '/usr/local/pkgs/mysqlmonitoragent-3.0.12.3016-linux-x86-64bit-update-installer.bin --optionfile /usr/local/pkgs/agent3.conf  --mode unattended ',
    path        => '/bin/:/usr/bin',
    user        => 'mysql',
    require     => File ['Agent3UpdatePkg'],
    subscribe   => Exec ['Agent3Installed'],
    refreshonly => true
  }

  exec { 'Change agent host id':
    alias     => 'ChangeAgentHostId',
    command   => "/bin/echo 'agent-host-id = ${::fqdn}' >> /opt/mysql/enterprise/agent3/etc/bootstrap.properties",
    path      => ['/bin', '/usr/bin'],
    cwd       => '/opt/mysql/enterprise/agent3/etc',
    #notify  => Service["mysql-monitor-agent3"],
    subscribe => Exec ['Agent3Updated' ],
    onlyif    => [
      '/usr/bin/test -f  /opt/mysql/enterprise/agent3/etc/bootstrap.properties',
      '/usr/bin/test `/bin/grep -i agent-host-id /opt/mysql/enterprise/agent3/etc/bootstrap.properties | /usr/bin/wc -l` -eq 0',
      ],
  }

  exec { 'Creating MySQL Monitor Agent 3 startup/stop script':
    command => 'cp /opt/mysql/enterprise/agent3/etc/init.d/mysql-monitor-agent /etc/init.d/',
    path    => '/bin/:/usr/bin',
    unless  => [ '/usr/bin/test -f /etc/init.d/mysql-monitor-agent'],
    onlyif  => [ '/usr/bin/test -f /opt/mysql/enterprise/agent3/etc/init.d/mysql-monitor-agent']
  }
}
