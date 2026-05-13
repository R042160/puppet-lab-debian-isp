require 'spec_helper'

describe 'isp_dovecot' do
  it { is_expected.to compile.with_all_deps }

  it { is_expected.to contain_package('dovecot-core').with_ensure('installed') }
  it { is_expected.to contain_package('dovecot-imapd').with_ensure('installed') }

  it { is_expected.to contain_group('vmail').with(gid: 5000, system: true) }

  it do
    is_expected.to contain_user('vmail')
      .with(uid: 5000, gid: 'vmail', home: '/var/mail/vhosts')
      .that_requires('Group[vmail]')
  end

  it do
    is_expected.to contain_file('/var/mail/vhosts')
      .with(ensure: 'directory', owner: 'vmail', group: 'vmail', mode: '0750')
      .that_requires('User[vmail]')
  end

  it do
    is_expected.to contain_file('/var/mail/vhosts/lab.local/labuser')
      .with(ensure: 'directory', owner: 'vmail', group: 'vmail', mode: '0750')
  end

  it do
    is_expected.to contain_file('/etc/dovecot/users')
      .with(owner: 'root', group: 'dovecot', mode: '0640')
      .with_content(%r{labuser@lab\.local:\{SHA512-CRYPT\}})
      .with_content(%r{:/var/mail/vhosts/lab.local/labuser::})
      .that_requires('Package[dovecot-core]')
      .that_notifies('Service[dovecot]')
  end

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
      .with_content(%r{driver = passwd-file})
      .with_content(%r{/etc/dovecot/users})
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

  it do
    is_expected.to contain_service('dovecot')
      .with(ensure: 'running', enable: true)
      .with_restart('/bin/sh -c "/usr/bin/doveadm reload || /usr/sbin/service dovecot start"')
  end
end
