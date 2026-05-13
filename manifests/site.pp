# Entrypoint manifest. Hiera decides which lab classes this node receives.
#
# Usage: puppet apply --certname=<node> --modulepath=/lab/modules /lab/manifests/site.pp

node default {
  $profile_classes = lookup('profile::classes', Array[String[1]], 'first', [
    'isp_bind',
    'isp_dhcp',
    'isp_postfix',
    'isp_nginx',
  ])

  include $profile_classes
}
