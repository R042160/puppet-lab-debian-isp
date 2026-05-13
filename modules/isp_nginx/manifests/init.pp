# == Class: isp_nginx
#
# Installs Nginx with a managed default vhost that serves a lab landing page.
# TLS is intentionally NOT configured at v0.1 (next learning step: certbot).
#
# $server_name MUST be provided via Hiera.
#
class isp_nginx (
  String $server_name,
) {

  package { 'nginx':
    ensure => installed,
  }

  file { '/var/www/html/index.html':
    ensure  => file,
    owner   => 'www-data',
    group   => 'www-data',
    mode    => '0644',
    content => epp('isp_nginx/index.html.epp', {
      'server_name' => $server_name,
    }),
    require => Package['nginx'],
  }

  file { '/etc/nginx/sites-available/default':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => epp('isp_nginx/default.epp', {
      'server_name' => $server_name,
    }),
    require => Package['nginx'],
    notify  => Service['nginx'],
  }

  service { 'nginx':
    ensure  => running,
    enable  => true,
    require => Package['nginx'],
  }
}
