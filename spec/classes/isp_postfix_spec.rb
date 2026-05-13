require 'spec_helper'

describe 'isp_postfix' do
  it { is_expected.to compile.with_all_deps }

  it { is_expected.to contain_package('debconf-utils').with_ensure('installed') }
  it { is_expected.to contain_package('postfix').with_ensure('installed') }

  it do
    is_expected.to contain_exec('preseed_postfix')
      .that_requires('Package[debconf-utils]')
      .that_comes_before('Package[postfix]')
  end

  it do
    is_expected.to contain_file('/etc/postfix/main.cf')
      .with(owner: 'root', group: 'root', mode: '0644')
      .with_content(%r{myhostname = puppet-lab\.local})
      .with_content(%r{mydomain   = lab\.local})
      .that_requires('Package[postfix]')
      .that_notifies('Service[postfix]')
  end

  it { is_expected.to contain_service('postfix').with(ensure: 'running', enable: true) }
end

