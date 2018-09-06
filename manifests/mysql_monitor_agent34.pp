# ========================================================================
# Module Name - hq_mysql
# ========================================================================
# $Id: $
# $HeadURL:$
# ========================================================================
# Install MySQL Enterprise Monitor Agent 3.4
class hq_mysql::mysql_monitor_agent34 {
  require hq_filesystem
  require hq_repositories::mainclass

  file { '/usr/local/pkgs/mysqlmonitoragent-3.4.2.4181-linux-x86-64bit-installer.bin':
    ensure => file,
    alias  => 'Agent34Pkg',
    owner  => root,
    group  => root,
    mode   => '0777',
    source => 'puppet:///modules/hq_mysql/pkgs/EM/mysqlmonitoragent-3.4.2.4181-linux-x86-64bit-installer.bin',
  }

  file { '/usr/local/pkgs/mysqlmonitoragent-3.4.2.4181-linux-x86-64bit-update-installer.bin':
    ensure => file,
    alias  => 'Agent34UpdatePkg',
    owner  => root,
    group  => root,
    mode   => '0777',
    source => 'puppet:///modules/hq_mysql/pkgs/EM/mysqlmonitoragent-3.4.2.4181-linux-x86-64bit-update-installer.bin',
  }

  file { '/usr/local/pkgs/agent34.conf':
    ensure  => file,
    alias   => 'Agent34Config',
    owner   => root,
    group   => root,
    mode    => '0777',
    content => template('hq_mysql/pkgs/EM/agent34.conf.erb'),
  }

  exec {'Install MySQL Enterprise Monitor Agent34':
    alias     => 'Agent34Installed',
    cwd       => '/usr/local/pkgs',
    command   =>  '/usr/local/pkgs/mysqlmonitoragent-3.4.2.4181-linux-x86-64bit-installer.bin --optionfile /usr/local/pkgs/agent34.conf  --mode unattended',
    path      => '/bin/:/usr/bin',
    user      => 'mysql',
    creates   => '/opt/mysql/enterprise/agent34',
    require   => File['Agent34Pkg'],
    logoutput => true,
  }

  exec {'Update MySQL Enterprise Monitor Agent34':
    alias       => 'Agent34Updated',
    cwd         => '/usr/local/pkgs',
    command     =>  '/usr/local/pkgs/mysqlmonitoragent-3.4.2.4181-linux-x86-64bit-update-installer.bin --optionfile /usr/local/pkgs/agent34.conf  --mode unattended ',
    path        => '/bin/:/usr/bin',
    user        => 'mysql',
    require     => File['Agent34UpdatePkg'],
    subscribe   => Exec['Agent34Installed'],
    refreshonly => true
  }

  exec { 'Change agent host id':
    alias     => 'ChangeAgentHostId',
    command   => "/bin/echo 'agent-host-id = ${::fqdn}' >> /opt/mysql/enterprise/agent34/etc/bootstrap.properties",
    path      => ['/bin', '/usr/bin'],
    cwd       => '/opt/mysql/enterprise/agent34/etc',
    #notify  => Service["mysql-monitor-agent34"],
    subscribe => Exec['Agent34Updated' ],
    onlyif    => [
      '/usr/bin/test -f  /opt/mysql/enterprise/agent34/etc/bootstrap.properties',
      '/usr/bin/test `/bin/grep -i agent-host-id /opt/mysql/enterprise/agent34/etc/bootstrap.properties | /usr/bin/wc -l` -eq 0',
      ],
  }
  # only execute once the update is installed
  exec { 'Set Java Option':
    alias     => 'JavaOption',
    command   => 'cp /opt/mysql/enterprise/agent34/bin/setenv.sh  /opt/mysql/enterprise/agent34/bin/setenv.sh.orig; sed -i "s/=\"-Xms32m -Xmx64m/=\"-Xss2M -Xms32m -Xmx64m/g" /opt/mysql/enterprise/agent34/bin/setenv.sh',
    path      => ['/bin', '/usr/bin'],
    cwd       => '/opt/mysql/enterprise/agent34/bin',
	subscribe => Exec['Agent34Updated' ],
	onlyif    => [ 
	   '/usr/bin/test ! -f  /opt/mysql/enterprise/agent34/bin/setenv.sh.orig' ,
	   '/usr/bin/test -f  /opt/mysql/enterprise/agent34/bin/setenv.sh', 
	  ],
  }
  
  exec { 'Creating MySQL Monitor Agent 34 startup/stop script':
    command => 'cp /opt/mysql/enterprise/agent34/etc/init.d/mysql-monitor-agent /etc/init.d/',
    path    => '/bin/:/usr/bin',
    unless  => [ '/usr/bin/test -f /etc/init.d/mysql-monitor-agent'],
    onlyif  => [ '/usr/bin/test -f /opt/mysql/enterprise/agent34/etc/init.d/mysql-monitor-agent']
  }
  
  
}
