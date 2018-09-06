# ========================================================================
# Module Name - hq_mysql
# ========================================================================
# $Id: bw_libaio.pp 40643 2015-04-21 21:50:16Z jwade $
# $HeadURL: http://svn.businesswire.com/svn/sysadmin/puppet/modules/hq_mysql/trunk/manifests/bw_libaio.pp $
# ========================================================================

class hq_mysql::bw_libaio{
  package {'libaio':
    ensure => 'installed'
        }
}

