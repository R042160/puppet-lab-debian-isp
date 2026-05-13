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
      .with_content(%r{home_mailbox = Maildir/})
      .with_content(%r{smtpd_sasl_type = dovecot})
      .with_content(%r{milter_protocol = 6})
      .with_content(%r{smtpd_milters = inet:127\.0\.0\.1:8891})
      .with_content(%r{non_smtpd_milters = inet:127\.0\.0\.1:8891})
      .that_requires('Package[postfix]')
      .that_notifies('Service[postfix]')
  end

  it do
    is_expected.to contain_file('/etc/postfix/master.cf')
      .with(owner: 'root', group: 'root', mode: '0644')
      .with_content(%r{^submission inet n\s+-\s+y\s+-\s+-\s+smtpd})
      .with_content(%r{smtpd_sasl_auth_enable=yes})
      .that_requires('Package[postfix]')
      .that_notifies('Service[postfix]')
  end

  it { is_expected.to contain_service('postfix').with(ensure: 'running', enable: true) }
end
