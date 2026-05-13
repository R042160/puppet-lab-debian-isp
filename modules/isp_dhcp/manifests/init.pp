# == Class: isp_dhcp
#
# Installs and configures isc-dhcp-server with a single sample subnet.
# This is a learning-lab setup; do not run on a real LAN segment.
#
# All parameters are MANDATORY and must be provided via Hiera.
# This is intentional: subnet / range / router are environment-specific
# data and must never be hard-coded in the manifest.
#
class isp_dhcp (
  String $subnet,
  String $netmask,
  String $range_start,
  String $range_end,
  String $router,
  Boolean $manage_service,
  Enum['running', 'stopped'] $service_ensure = 'running',
  Boolean $service_enable = true,
) {

  $dhcp_file_notify = $manage_service ? {
    true    => Service['isc-dhcp-server'],
    default => undef,
  }

  package { 'isc-dhcp-server':
    ensure => installed,
  }

  file { '/etc/dhcp/dhcpd.conf':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => epp('isp_dhcp/dhcpd.conf.epp', {
      'subnet'      => $subnet,
      'netmask'     => $netmask,
      'range_start' => $range_start,
      'range_end'   => $range_end,
      'router'      => $router,
    }),
    require => Package['isc-dhcp-server'],
    notify  => $dhcp_file_notify,
  }

  # In the Docker lab the service is not managed because no real LAN
  # interface is bound. A real node can enable service management via Hiera.
  if $manage_service {
    service { 'isc-dhcp-server':
      ensure  => $service_ensure,
      enable  => $service_enable,
      require => [ Package['isc-dhcp-server'], File['/etc/dhcp/dhcpd.conf'] ],
    }
  }
}
