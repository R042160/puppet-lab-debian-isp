# Entrypoint manifest. Hiera decides which lab classes this node receives.
#
# Usage: puppet apply --certname=<node> --modulepath=/lab/modules /lab/manifests/site.pp

node default {
  $profile_classes = lookup('profile::classes', Array[String[1]], 'first', [
    'isp_bind',
    'isp_dhcp',
    'isp_postfix',
    'isp_dovecot',
    'isp_opendkim',
    'isp_backup',
    'isp_monitoring',
    'isp_nginx',
  ])

  include $profile_classes

  if 'isp_postfix' in $profile_classes and 'isp_dovecot' in $profile_classes {
    Class['isp_postfix'] -> Class['isp_dovecot']
  }

  if 'isp_opendkim' in $profile_classes and 'isp_bind' in $profile_classes {
    Class['isp_opendkim'] -> Class['isp_bind']
  }

  if 'isp_opendkim' in $profile_classes and 'isp_postfix' in $profile_classes {
    Class['isp_opendkim'] -> Class['isp_postfix']
  }
}
