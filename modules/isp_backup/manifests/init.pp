# == Class: isp_backup
#
# Installs Restic and prepares a local lab repository with backup and
# restore-check scripts. The password is a dummy lab credential, not a secret.
#
class isp_backup (
  String[1] $repository,
  String[1] $password_file,
  String[1] $password,
  Array[String[1]] $backup_paths,
  Integer[1] $keep_daily = 7,
  Integer[1] $keep_weekly = 4,
  Integer[1] $keep_monthly = 6,
  Integer[1] $keep_yearly = 1,
  Boolean $prune = true,
) {

  package { 'restic':
    ensure => installed,
  }

  file { '/etc/restic':
    ensure  => directory,
    owner   => 'root',
    group   => 'root',
    mode    => '0700',
    require => Package['restic'],
  }

  file { '/var/backups/restic':
    ensure  => directory,
    owner   => 'root',
    group   => 'root',
    mode    => '0700',
    require => Package['restic'],
  }

  file { $repository:
    ensure  => directory,
    owner   => 'root',
    group   => 'root',
    mode    => '0700',
    require => File['/var/backups/restic'],
  }

  file { $password_file:
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0600',
    content => "${password}\n",
    require => File['/etc/restic'],
  }

  exec { 'init_restic_lab_repository':
    command => "/usr/bin/restic -r ${repository} --password-file ${password_file} init",
    creates => "${repository}/config",
    require => [
      Package['restic'],
      File[$repository],
      File[$password_file],
    ],
  }

  file { '/usr/local/sbin/lab-restic-backup':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
    content => epp('isp_backup/lab-restic-backup.epp', {
      'repository'    => $repository,
      'password_file' => $password_file,
      'backup_paths'  => $backup_paths,
    }),
    require => Exec['init_restic_lab_repository'],
  }

  file { '/usr/local/sbin/lab-restic-restore-check':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
    content => epp('isp_backup/lab-restic-restore-check.epp', {
      'repository'    => $repository,
      'password_file' => $password_file,
    }),
    require => Exec['init_restic_lab_repository'],
  }

  file { '/usr/local/sbin/lab-restic-retention':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
    content => epp('isp_backup/lab-restic-retention.epp', {
      'repository'    => $repository,
      'password_file' => $password_file,
      'keep_daily'    => $keep_daily,
      'keep_weekly'   => $keep_weekly,
      'keep_monthly'  => $keep_monthly,
      'keep_yearly'   => $keep_yearly,
      'prune'         => $prune,
    }),
    require => Exec['init_restic_lab_repository'],
  }
}
