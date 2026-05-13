require 'spec_helper'

describe 'isp_dhcp' do
  it { is_expected.to compile.with_all_deps }

  it { is_expected.to contain_package('isc-dhcp-server').with_ensure('installed') }

  it do
    is_expected.to contain_file('/etc/dhcp/dhcpd.conf')
      .with(owner: 'root', group: 'root', mode: '0644')
      .with_content(%r{subnet 192\.0\.2\.0 netmask 255\.255\.255\.0})
      .with_content(%r{range 192\.0\.2\.100 192\.0\.2\.200;})
      .with_content(%r{option routers 192\.0\.2\.1;})
      .that_requires('Package[isc-dhcp-server]')
      .that_notifies('Service[isc-dhcp-server]')
  end

  it { is_expected.to contain_service('isc-dhcp-server').with(ensure: 'running', enable: true) }
end

