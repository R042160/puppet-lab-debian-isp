require 'rspec-puppet'

repo_root = File.expand_path('..', __dir__)

RSpec.configure do |config|
  config.module_path = File.join(repo_root, 'modules')
  config.hiera_config = File.join(repo_root, 'hiera.yaml')
  config.strict_variables = true
  config.default_trusted_facts = {
    'certname' => 'puppet-lab.local',
  }

  config.default_facts = {
    'os' => {
      'name' => 'Debian',
      'family' => 'Debian',
      'release' => {
        'major' => '12',
        'full' => '12',
      },
      'distro' => {
        'codename' => 'bookworm',
      },
    },
    'osfamily' => 'Debian',
    'operatingsystem' => 'Debian',
    'operatingsystemrelease' => '12',
    'networking' => {
      'ip' => '192.0.2.10',
      'fqdn' => 'puppet-lab.local',
      'hostname' => 'puppet-lab',
    },
    'path' => '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin',
  }
end
