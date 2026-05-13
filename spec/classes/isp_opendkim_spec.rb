require 'spec_helper'

describe 'isp_opendkim' do
  it { is_expected.to compile.with_all_deps }

  it { is_expected.to contain_package('opendkim').with_ensure('installed') }
  it { is_expected.to contain_package('opendkim-tools').with_ensure('installed') }

  it do
    is_expected.to contain_file('/etc/opendkim/keys/lab.local')
      .with(ensure: 'directory', owner: 'opendkim', group: 'opendkim', mode: '0755')
      .that_requires('Package[opendkim]')
  end

  it do
    is_expected.to contain_exec('generate_opendkim_key_lab.local_default')
      .with_command('/usr/sbin/opendkim-genkey -D /etc/opendkim/keys/lab.local -d lab.local -s default')
      .with_creates('/etc/opendkim/keys/lab.local/default.private')
      .that_requires('Package[opendkim-tools]')
  end

  it do
    is_expected.to contain_file('/etc/opendkim/keys/lab.local/default.private')
      .with(owner: 'opendkim', group: 'opendkim', mode: '0640')
      .that_requires('Exec[generate_opendkim_key_lab.local_default]')
      .that_notifies('Service[opendkim]')
  end

  it do
    is_expected.to contain_file('/etc/opendkim/keys/lab.local/default.txt')
      .with(owner: 'opendkim', group: 'opendkim', mode: '0644')
      .that_requires('Exec[generate_opendkim_key_lab.local_default]')
  end

  it do
    is_expected.to contain_file('/etc/opendkim.conf')
      .with_content(%r{Socket\s+inet:8891@127\.0\.0\.1})
      .with_content(%r{KeyTable\s+file:/etc/opendkim/key\.table})
      .with_content(%r{SigningTable\s+refile:/etc/opendkim/signing\.table})
      .that_requires('Package[opendkim]')
      .that_notifies('Service[opendkim]')
  end

  it do
    is_expected.to contain_file('/etc/opendkim/key.table')
      .with_content(%r{default\._domainkey\.lab\.local lab\.local:default:/etc/opendkim/keys/lab\.local/default\.private})
  end

  it do
    is_expected.to contain_file('/etc/opendkim/signing.table')
      .with_content(%r{\*@lab\.local default\._domainkey\.lab\.local})
  end

  it do
    is_expected.to contain_file('/etc/opendkim/trusted.hosts')
      .with_content(%r{172\.28\.53\.0/24})
      .with_content(%r{\*\.lab\.local})
  end

  it { is_expected.to contain_service('opendkim').with(ensure: 'running', enable: true) }
end
