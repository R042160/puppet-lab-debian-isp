# == Class: isp_bind
#
# Installs BIND9 and applies a minimal authoritative-server configuration
# suitable for a learning lab. NOT production-hardened.
#
# Idempotent: a second puppet apply produces 0 events.
#
# Parameters are resolved via Hiera automatic parameter lookup
# (key: isp_bind::<param>). The manifest default below acts as a
# resilient fallback if Hiera does not provide a value.
#
class isp_bind (
  Boolean $listen_v6 = true,
) {

  package { 'bind9':
    ensure => installed,
  }

  file { '/etc/bind/named.conf.options':
    ensure  => file,
    owner   => 'root',
    group   => 'bind',
    mode    => '0644',
    content => epp('isp_bind/named.conf.options.epp', {
      'listen_v6' => $listen_v6,
    }),
    require => Package['bind9'],
    notify  => Service['bind9'],
  }

  service { 'bind9':
    ensure  => running,
    enable  => true,
    require => Package['bind9'],
  }
}
