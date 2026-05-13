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
      .with_content(%r{allow-transfer \{ 172\.28\.53\.11; \};})
      .with_content(%r{also-notify \{ 172\.28\.53\.11; \};})
      .that_requires('Package[bind9]')
      .that_notifies('Service[named]')
  end

  it do
    is_expected.to contain_file('/etc/bind/zones/db.lab.local')
      .with(owner: 'root', group: 'bind', mode: '0644')
      .with_content(%r{\$TTL 300})
      .with_content(%r{@ IN SOA ns1\.lab\.local\. hostmaster\.lab\.local\.})
      .with_content(%r{2026051302 ; serial})
      .with_content(%r{@ IN NS ns1\.lab\.local\.})
      .with_content(%r{@ IN NS ns2\.lab\.local\.})
      .with_content(%r{@ IN MX 10 mail\.lab\.local\.})
      .with_content(%r{@ IN TXT "v=spf1 mx -all"})
      .with_content(%r{_dmarc IN TXT "v=DMARC1; p=none; rua=mailto:postmaster@lab\.local"})
      .with_content(%r{\$INCLUDE /etc/opendkim/keys/lab\.local/default\.txt})
      .with_content(%r{www IN A 192\.0\.2\.20})
      .with_content(%r{ns1 IN A 172\.28\.53\.10})
      .with_content(%r{ns2 IN A 172\.28\.53\.11})
      .with_content(%r{ns1 IN AAAA 2001:db8::10})
      .that_requires('File[/etc/bind/zones]')
      .that_notifies('Service[named]')
  end

  it { is_expected.to contain_service('named').with(ensure: 'running', enable: true) }

  context 'with a secondary zone' do
    let(:params) do
      {
        'zones' => {
          'lab.local' => {
            'role' => 'secondary',
            'masters' => ['172.28.53.10'],
          },
        },
      }
    end

    it { is_expected.to compile.with_all_deps }

    it do
      is_expected.to contain_file('/etc/bind/named.conf.local')
        .with_content(%r{zone "lab\.local"})
        .with_content(%r{type slave;})
        .with_content(%r{file "/var/cache/bind/db\.lab\.local";})
        .with_content(%r{masters \{ 172\.28\.53\.10; \};})
        .that_requires('Package[bind9]')
        .that_notifies('Service[named]')
    end

    it { is_expected.not_to contain_file('/etc/bind/zones/db.lab.local') }
  end
end
