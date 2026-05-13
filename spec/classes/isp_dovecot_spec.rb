require 'spec_helper'

describe 'isp_dovecot' do
  it { is_expected.to compile.with_all_deps }

  it { is_expected.to contain_package('dovecot-core').with_ensure('installed') }
  it { is_expected.to contain_package('dovecot-imapd').with_ensure('installed') }

  it do
    is_expected.to contain_file('/etc/dovecot/conf.d/99-lab-mail.conf')
      .with(owner: 'root', group: 'root', mode: '0644')
      .with_content(%r{mail_location = maildir:~/Maildir})
      .that_requires('Package[dovecot-core]')
      .that_notifies('Service[dovecot]')
  end

  it do
    is_expected.to contain_file('/etc/dovecot/conf.d/99-lab-auth.conf')
      .with_content(%r{disable_plaintext_auth = no})
      .with_content(%r{auth_mechanisms = plain login})
  end

  it do
    is_expected.to contain_file('/etc/dovecot/conf.d/99-postfix-auth.conf')
      .with_content(%r{unix_listener /var/spool/postfix/private/auth})
      .with_content(%r{user = postfix})
      .with_content(%r{group = postfix})
  end

  it do
    is_expected.to contain_file('/etc/dovecot/conf.d/99-lab-ssl.conf')
      .with_content(%r{ssl = no})
  end

  it { is_expected.to contain_service('dovecot').with(ensure: 'running', enable: true) }
end
