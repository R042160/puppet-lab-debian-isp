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
  Hash[String[1], Hash] $zones,
  Boolean $listen_v6 = true,
) {

  $primary_zones = $zones.filter |String $zone_name, Hash $zone| {
    if $zone['role'] {
      $zone['role'] == 'primary'
    } else {
      true
    }
  }

  $primary_zone_file_paths = $primary_zones.keys.map |String $zone_name| {
    "/etc/bind/zones/db.${zone_name}"
  }

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
    notify  => Service['named'],
  }

  file { '/etc/bind/zones':
    ensure  => directory,
    owner   => 'root',
    group   => 'bind',
    mode    => '0755',
    require => Package['bind9'],
  }

  $primary_zones.each |String $zone_name, Hash $zone| {
    file { "/etc/bind/zones/db.${zone_name}":
      ensure       => file,
      owner        => 'root',
      group        => 'bind',
      mode         => '0644',
      content      => epp('isp_bind/db.zone.epp', {
        'zone_name' => $zone_name,
        'zone'      => $zone,
      }),
      validate_cmd => "/usr/bin/named-checkzone ${zone_name} %",
      require      => File['/etc/bind/zones'],
      notify       => Service['named'],
    }
  }

  if empty($primary_zone_file_paths) {
    $named_conf_require = Package['bind9']
    $service_require = [
      Package['bind9'],
      File['/etc/bind/named.conf.options'],
      File['/etc/bind/named.conf.local'],
    ]
  } else {
    $named_conf_require = [Package['bind9'], File[$primary_zone_file_paths]]
    $service_require = [
      Package['bind9'],
      File['/etc/bind/named.conf.options'],
      File['/etc/bind/named.conf.local'],
      File[$primary_zone_file_paths],
    ]
  }

  file { '/etc/bind/named.conf.local':
    ensure  => file,
    owner   => 'root',
    group   => 'bind',
    mode    => '0644',
    content => epp('isp_bind/named.conf.local.epp', {
      'zones' => $zones,
    }),
    require => $named_conf_require,
    notify  => Service['named'],
  }

  service { 'named':
    ensure  => running,
    enable  => true,
    require => $service_require,
  }
}
