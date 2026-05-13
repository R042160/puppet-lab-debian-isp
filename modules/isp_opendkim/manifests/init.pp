# == Class: isp_opendkim
#
# Installs OpenDKIM for lab mail signing. Key material is generated locally on
# the managed node and is not stored in this repository.
#
class isp_opendkim (
  String[1] $domain,
  String[1] $selector = 'default',
  String[1] $socket = 'inet:8891@127.0.0.1',
  Array[String[1]] $trusted_hosts = ['127.0.0.1', 'localhost'],
) {

  $key_dir = "/etc/opendkim/keys/${domain}"
  $private_key = "${key_dir}/${selector}.private"
  $public_record = "${key_dir}/${selector}.txt"
  $key_name = "${selector}._domainkey.${domain}"

  package { ['opendkim', 'opendkim-tools']:
    ensure => installed,
  }

  file { [
      '/etc/opendkim',
      '/etc/opendkim/keys',
      $key_dir,
    ]:
    ensure  => directory,
    owner   => 'opendkim',
    group   => 'opendkim',
    mode    => '0755',
    require => Package['opendkim'],
  }

  exec { "generate_opendkim_key_${domain}_${selector}":
    command => "/usr/sbin/opendkim-genkey -D ${key_dir} -d ${domain} -s ${selector}",
    creates => $private_key,
    path    => ['/usr/sbin', '/usr/bin', '/sbin', '/bin'],
    require => [
      Package['opendkim-tools'],
      File[$key_dir],
    ],
  }

  file { $private_key:
    ensure  => file,
    owner   => 'opendkim',
    group   => 'opendkim',
    mode    => '0640',
    require => Exec["generate_opendkim_key_${domain}_${selector}"],
    notify  => Service['opendkim'],
  }

  file { $public_record:
    ensure  => file,
    owner   => 'opendkim',
    group   => 'opendkim',
    mode    => '0644',
    require => Exec["generate_opendkim_key_${domain}_${selector}"],
  }

  file { '/etc/opendkim.conf':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => epp('isp_opendkim/opendkim.conf.epp', {
      'socket' => $socket,
    }),
    require => Package['opendkim'],
    notify  => Service['opendkim'],
  }

  file { '/etc/opendkim/key.table':
    ensure  => file,
    owner   => 'root',
    group   => 'opendkim',
    mode    => '0644',
    content => epp('isp_opendkim/key.table.epp', {
      'domain'      => $domain,
      'selector'    => $selector,
      'key_name'    => $key_name,
      'private_key' => $private_key,
    }),
    require => Package['opendkim'],
    notify  => Service['opendkim'],
  }

  file { '/etc/opendkim/signing.table':
    ensure  => file,
    owner   => 'root',
    group   => 'opendkim',
    mode    => '0644',
    content => epp('isp_opendkim/signing.table.epp', {
      'domain'   => $domain,
      'key_name' => $key_name,
    }),
    require => Package['opendkim'],
    notify  => Service['opendkim'],
  }

  file { '/etc/opendkim/trusted.hosts':
    ensure  => file,
    owner   => 'root',
    group   => 'opendkim',
    mode    => '0644',
    content => epp('isp_opendkim/trusted.hosts.epp', {
      'trusted_hosts' => $trusted_hosts,
    }),
    require => Package['opendkim'],
    notify  => Service['opendkim'],
  }

  service { 'opendkim':
    ensure  => running,
    enable  => true,
    require => [
      Package['opendkim'],
      File['/etc/opendkim.conf'],
      File['/etc/opendkim/key.table'],
      File['/etc/opendkim/signing.table'],
      File['/etc/opendkim/trusted.hosts'],
      File[$private_key],
    ],
  }
}
