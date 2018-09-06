
class hq_mysql::mysql_sshkey_public{
  require hq_users

  ssh_authorized_key { 'mysql':
    user   => 'mysql',
    type   => 'ssh-dss',
    target => '/home/mysql/.ssh/authorized_keys',
    key    => 'AAAAB3NzaC1kc3MAAACBAPNAjXl0npTdcQO8dF/1x/pU9yf7rwW6OaYxEJCMiNl4PCDYcKfY+D80pm3rmA+xfN9OWOr3exBtK5aVGuQSu0HfHL2JaacPwsexq/OgyPyZKWNrU4/r3cA/Dz8b2PSD32U0/FczjwrQXDBMq/DHVwsrz3GTAKh2masbObPin2o3AAAAFQDg0i7dV2P00cDq9emzoGDj/8/TbQAAAIBsNodB2p2o940nqyda6jjzcaURV7PU1DZs9IluNtr3BfG3OJksMrTgS4j1WgkkfKfAxpK6VqICAtkTkPx/FW7dW0zWgE2HtNo6s0utfsuo/o6s2WRksGmwa6kHD4L2qL6WdKni+7O6boRPqJnhp3N2ZAc6SjkDC94RlluCcG81WgAAAIB5EfXNivWEp4OBn9oAATvYptfnBmShPdzgLbQaqSXPQVpFtwSBuikEVbTjEb6Kjzb2j/agugKvym1tnnU0M1swSIMdic7uVgDCQMkLALtdgf5X+8YXkhI/fBS369plXu6KL3fwWT6fTxtVpV3rGQyGetZ+RCDVHtQC3zxuYb1gXg=='
  }
}
