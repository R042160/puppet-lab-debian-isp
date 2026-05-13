# == Class: isp_monitoring
#
# Installs Prometheus Node Exporter and publishes lab-specific health metrics
# through the textfile collector.
#
class isp_monitoring (
  String[1] $listen_address = '0.0.0.0:9100',
  String[1] $textfile_directory = '/var/lib/node_exporter/textfile_collector',
  String[1] $metrics_file = '/var/lib/node_exporter/textfile_collector/puppet_lab.prom',
  Array[String[1]] $services = [],
  Hash[String[1], Hash[String[1], Variant[String[1], Integer[1]]]] $tcp_checks = {},
) {

  package { 'prometheus-node-exporter':
    ensure => installed,
  }

  file { '/var/lib/node_exporter':
    ensure  => directory,
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
    require => Package['prometheus-node-exporter'],
  }

  file { $textfile_directory:
    ensure  => directory,
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
    require => File['/var/lib/node_exporter'],
  }

  file { '/etc/default/prometheus-node-exporter':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => epp('isp_monitoring/prometheus-node-exporter.default.epp', {
      'listen_address'     => $listen_address,
      'textfile_directory' => $textfile_directory,
    }),
    require => Package['prometheus-node-exporter'],
    notify  => Service['prometheus-node-exporter'],
  }

  file { '/usr/local/sbin/lab-monitoring-check':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
    content => epp('isp_monitoring/lab-monitoring-check.epp', {
      'metrics_file' => $metrics_file,
      'services'     => $services,
      'tcp_checks'   => $tcp_checks,
    }),
    require => File[$textfile_directory],
  }

  exec { 'write_initial_puppet_lab_metrics':
    command     => '/usr/local/sbin/lab-monitoring-check',
    refreshonly => true,
    subscribe   => File['/usr/local/sbin/lab-monitoring-check'],
  }

  service { 'prometheus-node-exporter':
    ensure  => running,
    enable  => true,
    require => [
      Package['prometheus-node-exporter'],
      File['/etc/default/prometheus-node-exporter'],
      File[$textfile_directory],
    ],
  }
}
