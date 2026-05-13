# Entrypoint manifest. Applies all four ISP modules to this node.
#
# Usage: puppet apply --modulepath=/lab/modules /lab/manifests/site.pp

node default {
  include isp_bind
  include isp_dhcp
  include isp_postfix
  include isp_nginx
}
