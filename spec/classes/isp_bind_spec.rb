require 'spec_helper'

describe 'isp_bind' do
  it { is_expected.to compile.with_all_deps }

  it { is_expected.to contain_package('bind9').with_ensure('installed') }

  it do
    is_expected.to contain_file('/etc/bind/named.conf.options')
      .with(owner: 'root', group: 'bind', mode: '0644')
      .with_content(%r{recursion no;})
      .with_content(%r{listen-on-v6 \{ any; \};})
      .that_requires('Package[bind9]')
      .that_notifies('Service[bind9]')
  end

  it { is_expected.to contain_service('bind9').with(ensure: 'running', enable: true) }
end

