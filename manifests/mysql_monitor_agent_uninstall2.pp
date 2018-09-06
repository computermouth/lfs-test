# ========================================================================
# Module Name - hq_mysql
# ========================================================================
# $Id: mysql_monitor_agent_uninstall2.pp 40643 2015-04-21 21:50:16Z jwade $
# $HeadURL: http://svn.businesswire.com/svn/sysadmin/puppet/modules/hq_mysql/trunk/manifests/mysql_monitor_agent_uninstall2.pp $
# ========================================================================
# Remove MySQL Monitor Agent 2.x
class hq_mysql::mysql_monitor_agent_uninstall2 {

  file { '/usr/local/pkgs/mysqlmonitoragent-2.3.12.2174-linux-glibc2.3-x86-64bit-installer.bin':
        ensure  => absent,
  }

  file { '/usr/local/pkgs/mysqlmonitoragent-2.3.12.2174-linux-glibc2.3-x86-64bit-update-installer.bin':
        ensure  =>  absent,
  }

  exec {'Uninstall MySQL Enterprise Monitor Agent2':
    alias   => 'removeAgent2',
    command =>  '/opt/mysql/enterprise/agent/uninstall --mode unattended ',
    path    => '/bin/:/usr/bin',
    onlyif  => [ 'test -f /opt/mysql/enterprise/agent/uninstall' ],
  }
}
