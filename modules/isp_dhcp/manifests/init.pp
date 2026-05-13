# == Class: isp_dhcp
#
# Installs and configures isc-dhcp-server with a single sample subnet.
# This is a learning-lab setup; do not run on a real LAN segment.
#
class isp_dhcp (
  String $subnet  = '192.0.2.0',
  String $netmask = '255.255.255.0',
  String $range_start = '192.0.2.100',
  String $range_end   = '192.0.2.200',
  String $router      = '192.0.2.1',
) {

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
    notify  => Service['isc-dhcp-server'],
  }

  # Service may fail to start without a real bound interface — that's expected
  # in a single-container lab. We still declare the resource so the manifest
  # stays honest about intent.
  service { 'isc-dhcp-server':
    ensure  => running,
    enable  => true,
    require => [ Package['isc-dhcp-server'], File['/etc/dhcp/dhcpd.conf'] ],
  }
}
