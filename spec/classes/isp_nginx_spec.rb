require 'spec_helper'

describe 'isp_nginx' do
  it { is_expected.to compile.with_all_deps }

  it { is_expected.to contain_package('nginx').with_ensure('installed') }

  it do
    is_expected.to contain_file('/var/www/html/index.html')
      .with(owner: 'www-data', group: 'www-data', mode: '0644')
      .with_content(%r{Host: <code>puppet-lab\.local</code>})
      .that_requires('Package[nginx]')
  end

  it do
    is_expected.to contain_file('/etc/nginx/sites-available/default')
      .with(owner: 'root', group: 'root', mode: '0644')
      .with_content(%r{server_name puppet-lab\.local;})
      .that_requires('Package[nginx]')
      .that_notifies('Service[nginx]')
  end

  it { is_expected.to contain_service('nginx').with(ensure: 'running', enable: true) }
end

