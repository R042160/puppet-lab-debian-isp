# == Class: isp_postfix
#
# Installs Postfix with a local-only delivery profile. No internet relay.
# DKIM/SPF/DMARC are explicit next-step learnings, not part of v0.1.
#
# myhostname / mydomain MUST be provided via Hiera — they are
# environment-specific.
#
class isp_postfix (
  String $myhostname,
  String $mydomain,
) {

  # debconf preseeding so postfix install is fully non-interactive
  package { 'debconf-utils':
    ensure => installed,
  }

  exec { 'preseed_postfix':
    command => "/bin/echo 'postfix postfix/main_mailer_type select Local only' | /usr/bin/debconf-set-selections && /bin/echo \"postfix postfix/mailname string ${myhostname}\" | /usr/bin/debconf-set-selections",
    unless  => '/usr/bin/debconf-show postfix 2>/dev/null | /bin/grep -q "Local only"',
    require => Package['debconf-utils'],
    before  => Package['postfix'],
  }

  package { 'postfix':
    ensure => installed,
  }

  file { '/etc/postfix/main.cf':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => epp('isp_postfix/main.cf.epp', {
      'myhostname' => $myhostname,
      'mydomain'   => $mydomain,
    }),
    require => Package['postfix'],
    notify  => Service['postfix'],
  }

  service { 'postfix':
    ensure  => running,
    enable  => true,
    require => Package['postfix'],
  }
}
