# == Class: isp_dovecot
#
# Installs Dovecot for a lab Maildir + IMAP/Auth setup. The auth socket is
# exposed inside Postfix's chroot so Postfix submission can use Dovecot SASL.
#
class isp_dovecot (
  String[1] $mail_location = 'maildir:~/Maildir',
  Boolean $disable_plaintext_auth = false,
  Array[String[1]] $auth_mechanisms = ['plain', 'login'],
) {

  package { ['dovecot-core', 'dovecot-imapd']:
    ensure => installed,
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
    require => [
      Package['dovecot-core'],
      Package['dovecot-imapd'],
      File['/etc/dovecot/conf.d/99-lab-mail.conf'],
      File['/etc/dovecot/conf.d/99-lab-auth.conf'],
      File['/etc/dovecot/conf.d/99-postfix-auth.conf'],
      File['/etc/dovecot/conf.d/99-lab-ssl.conf'],
    ],
  }
}
