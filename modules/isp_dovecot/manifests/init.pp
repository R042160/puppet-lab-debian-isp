# == Class: isp_dovecot
#
# Installs Dovecot for a lab Maildir + IMAP/Auth setup. The auth socket is
# exposed inside Postfix's chroot so Postfix submission can use Dovecot SASL.
#
class isp_dovecot (
  String[1] $mail_location = 'maildir:~/Maildir',
  Boolean $disable_plaintext_auth = false,
  Array[String[1]] $auth_mechanisms = ['plain', 'login'],
  Integer[1] $virtual_uid = 5000,
  Integer[1] $virtual_gid = 5000,
  String[1] $virtual_mail_root = '/var/mail/vhosts',
  String[1] $virtual_mail_domain = 'lab.local',
  Hash[String[1], Hash[String[1], String[1]]] $lab_users = {},
) {

  package { ['dovecot-core', 'dovecot-imapd']:
    ensure => installed,
  }

  group { 'vmail':
    ensure => present,
    gid    => $virtual_gid,
    system => true,
  }

  user { 'vmail':
    ensure     => present,
    uid        => $virtual_uid,
    gid        => 'vmail',
    home       => $virtual_mail_root,
    managehome => false,
    shell      => '/usr/sbin/nologin',
    system     => true,
    require    => Group['vmail'],
  }

  file { $virtual_mail_root:
    ensure  => directory,
    owner   => 'vmail',
    group   => 'vmail',
    mode    => '0750',
    require => User['vmail'],
  }

  file { "${virtual_mail_root}/${virtual_mail_domain}":
    ensure  => directory,
    owner   => 'vmail',
    group   => 'vmail',
    mode    => '0750',
    require => File[$virtual_mail_root],
  }

  $lab_users.each |String $username, Hash[String[1], String[1]] $user| {
    file { $user['home']:
      ensure  => directory,
      owner   => 'vmail',
      group   => 'vmail',
      mode    => '0750',
      require => File["${virtual_mail_root}/${virtual_mail_domain}"],
    }
  }

  file { '/etc/dovecot/users':
    ensure  => file,
    owner   => 'root',
    group   => 'dovecot',
    mode    => '0640',
    content => epp('isp_dovecot/users.epp', {
      'lab_users'   => $lab_users,
      'virtual_uid' => $virtual_uid,
      'virtual_gid' => $virtual_gid,
    }),
    require => [
      Package['dovecot-core'],
      User['vmail'],
    ],
    notify  => Service['dovecot'],
  }

  file { '/etc/dovecot/conf.d/99-lab-mail.conf':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => epp('isp_dovecot/99-lab-mail.conf.epp', {
      'mail_location' => $mail_location,
    }),
    require => Package['dovecot-core'],
    notify  => Service['dovecot'],
  }

  file { '/etc/dovecot/conf.d/99-lab-auth.conf':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => epp('isp_dovecot/99-lab-auth.conf.epp', {
      'disable_plaintext_auth' => $disable_plaintext_auth,
      'auth_mechanisms'        => $auth_mechanisms,
      'lab_users'              => $lab_users,
    }),
    require => Package['dovecot-core'],
    notify  => Service['dovecot'],
  }

  file { '/etc/dovecot/conf.d/99-postfix-auth.conf':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => epp('isp_dovecot/99-postfix-auth.conf.epp'),
    require => Package['dovecot-core'],
    notify  => Service['dovecot'],
  }

  file { '/etc/dovecot/conf.d/99-lab-ssl.conf':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => epp('isp_dovecot/99-lab-ssl.conf.epp'),
    require => Package['dovecot-core'],
    notify  => Service['dovecot'],
  }

  service { 'dovecot':
    ensure  => running,
    enable  => true,
    restart => '/bin/sh -c "/usr/bin/doveadm reload || /usr/sbin/service dovecot start"',
    require => [
      Package['dovecot-core'],
      Package['dovecot-imapd'],
      File['/etc/dovecot/conf.d/99-lab-mail.conf'],
      File['/etc/dovecot/conf.d/99-lab-auth.conf'],
      File['/etc/dovecot/conf.d/99-postfix-auth.conf'],
      File['/etc/dovecot/conf.d/99-lab-ssl.conf'],
      File['/etc/dovecot/users'],
    ],
  }
}
