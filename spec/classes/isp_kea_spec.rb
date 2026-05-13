require 'spec_helper'

describe 'isp_kea' do
  it { is_expected.to compile.with_all_deps }

  it { is_expected.to contain_package('kea-dhcp4-server').with_ensure('installed') }

  it do
    is_expected.to contain_file('/etc/kea')
      .with(ensure: 'directory', owner: 'root', group: 'root', mode: '0755')
      .that_requires('Package[kea-dhcp4-server]')
  end

  it do
    is_expected.to contain_file('/etc/kea/kea-dhcp4.conf')
      .with(owner: 'root', group: 'root', mode: '0644')
      .with_content(%r{"subnet": "192\.0\.2\.0/24"})
      .with_content(%r{"pool": "192\.0\.2\.100 - 192\.0\.2\.200"})
      .with_content(%r{"name": "domain-name-servers"})
      .with_content(%r{"data": "9\.9\.9\.9, 1\.1\.1\.1"})
      .that_requires('File[/etc/kea]')
  end

  it do
    is_expected.to contain_exec('validate_kea_dhcp4_config')
      .with_command('/usr/sbin/kea-dhcp4 -t /etc/kea/kea-dhcp4.conf')
      .with_refreshonly(true)
      .that_subscribes_to('File[/etc/kea/kea-dhcp4.conf]')
  end

  it { is_expected.not_to contain_service('kea-dhcp4-server') }
end
