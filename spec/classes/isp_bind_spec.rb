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
      .that_notifies('Service[named]')
  end

  it do
    is_expected.to contain_file('/etc/bind/zones')
      .with(ensure: 'directory', owner: 'root', group: 'bind', mode: '0755')
      .that_requires('Package[bind9]')
  end

  it do
    is_expected.to contain_file('/etc/bind/named.conf.local')
      .with(owner: 'root', group: 'bind', mode: '0644')
      .with_content(%r{zone "lab\.local"})
      .with_content(%r{type master;})
      .with_content(%r{file "/etc/bind/zones/db\.lab\.local";})
      .with_content(%r{allow-transfer \{ 192\.0\.2\.11; \};})
      .that_requires('Package[bind9]')
      .that_notifies('Service[named]')
  end

  it do
    is_expected.to contain_file('/etc/bind/zones/db.lab.local')
      .with(owner: 'root', group: 'bind', mode: '0644')
      .with_content(%r{\$TTL 300})
      .with_content(%r{@ IN SOA ns1\.lab\.local\. hostmaster\.lab\.local\.})
      .with_content(%r{2026051301 ; serial})
      .with_content(%r{@ IN NS ns1\.lab\.local\.})
      .with_content(%r{@ IN MX 10 mail\.lab\.local\.})
      .with_content(%r{www IN A 192\.0\.2\.20})
      .with_content(%r{ns1 IN AAAA 2001:db8::10})
      .that_requires('File[/etc/bind/zones]')
      .that_notifies('Service[named]')
  end

  it { is_expected.to contain_service('named').with(ensure: 'running', enable: true) }
end
