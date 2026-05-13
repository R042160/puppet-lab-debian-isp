# == Class: isp_postfix
#
# Installs Postfix with lab submission support. No internet relay.
# DKIM/SPF/DMARC are explicit next-step learnings, not part of this module.
#
# myhostname / mydomain MUST be provided via Hiera — they are
# environment-specific.
#
class isp_postfix (
  String $myhostname,
  String $mydomain,
  Boolean $submission_enabled = true,
  Boolean $dkim_milter_enabled = false,
  String[1] $dkim_milter_socket = 'inet:127.0.0.1:8891',
) {

  $preseed_mailer_type = "/bin/echo 'postfix postfix/main_mailer_type select Local only' | /usr/bin/debconf-set-selections"
  $preseed_mailname    = "/bin/echo \"postfix postfix/mailname string ${myhostname}\" | /usr/bin/debconf-set-selections"

  # debconf preseeding so postfix install is fully non-interactive
  package { 'debconf-utils':
    ensure => installed,
  }

  exec { 'preseed_postfix':
    command => "${preseed_mailer_type} && ${preseed_mailname}",
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
      'myhostname'          => $myhostname,
      'mydomain'            => $mydomain,
      'submission_enabled'  => $submission_enabled,
      'dkim_milter_enabled' => $dkim_milter_enabled,
      'dkim_milter_socket'  => $dkim_milter_socket,
    }),
    require => Package['postfix'],
    notify  => Service['postfix'],
  }

  file { '/etc/postfix/master.cf':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => epp('isp_postfix/master.cf.epp', {
      'submission_enabled' => $submission_enabled,
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
