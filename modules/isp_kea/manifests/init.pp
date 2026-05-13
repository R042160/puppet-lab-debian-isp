# == Class: isp_kea
#
# Installs Kea DHCPv4 and renders a single lab subnet. In Docker, service
# management stays disabled by default to avoid binding DHCP on a host LAN.
#
class isp_kea (
  String[1] $subnet_cidr,
  String[1] $range_start,
  String[1] $range_end,
  String[1] $router,
  Array[String[1]] $dns_servers,
  String[1] $domain_name,
  Boolean $manage_service,
  Enum['running', 'stopped'] $service_ensure = 'running',
  Boolean $service_enable = true,
) {

  $kea_service = 'kea-dhcp4-server'
  $kea_file_notify = $manage_service ? {
    true    => Service[$kea_service],
    default => undef,
  }

  package { 'kea-dhcp4-server':
    ensure => installed,
  }

  file { '/etc/kea':
    ensure  => directory,
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
    require => Package['kea-dhcp4-server'],
  }

  file { '/etc/kea/kea-dhcp4.conf':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => epp('isp_kea/kea-dhcp4.conf.epp', {
      'subnet_cidr' => $subnet_cidr,
      'range_start' => $range_start,
      'range_end'   => $range_end,
      'router'      => $router,
      'dns_servers' => $dns_servers,
      'domain_name' => $domain_name,
    }),
    require => File['/etc/kea'],
    notify  => $kea_file_notify,
  }

  exec { 'validate_kea_dhcp4_config':
    command     => '/usr/sbin/kea-dhcp4 -t /etc/kea/kea-dhcp4.conf',
    refreshonly => true,
    subscribe   => File['/etc/kea/kea-dhcp4.conf'],
    require     => [Package['kea-dhcp4-server'], File['/etc/kea/kea-dhcp4.conf']],
  }

  if $manage_service {
    service { $kea_service:
      ensure  => $service_ensure,
      enable  => $service_enable,
      require => [Package['kea-dhcp4-server'], File['/etc/kea/kea-dhcp4.conf']],
    }
  }
}
