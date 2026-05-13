require 'spec_helper'

describe 'isp_backup' do
  it { is_expected.to compile.with_all_deps }

  it { is_expected.to contain_package('restic').with_ensure('installed') }

  it do
    is_expected.to contain_file('/etc/restic')
      .with(ensure: 'directory', owner: 'root', group: 'root', mode: '0700')
      .that_requires('Package[restic]')
  end

  it do
    is_expected.to contain_file('/var/backups/restic/lab-repo')
      .with(ensure: 'directory', owner: 'root', group: 'root', mode: '0700')
      .that_requires('File[/var/backups/restic]')
  end

  it do
    is_expected.to contain_file('/etc/restic/lab-password')
      .with(owner: 'root', group: 'root', mode: '0600')
      .with_content(%r{lab-restic-passphrase})
      .that_requires('File[/etc/restic]')
  end

  it do
    is_expected.to contain_exec('init_restic_lab_repository')
      .with_command('/usr/bin/restic -r /var/backups/restic/lab-repo --password-file /etc/restic/lab-password init')
      .with_creates('/var/backups/restic/lab-repo/config')
      .that_requires('Package[restic]')
  end

  it do
    is_expected.to contain_file('/usr/local/sbin/lab-restic-backup')
      .with(owner: 'root', group: 'root', mode: '0755')
      .with_content(%r{restic -r "\$\{repository\}" --password-file "\$\{password_file\}"})
      .with_content(%r{'/etc/bind'})
      .with_content(%r{'/etc/opendkim'})
      .that_requires('Exec[init_restic_lab_repository]')
  end

  it do
    is_expected.to contain_file('/usr/local/sbin/lab-restic-restore-check')
      .with(owner: 'root', group: 'root', mode: '0755')
      .with_content(%r{restore latest --target "\$\{restore_target\}"})
      .with_content(%r{named\.conf\.local})
      .that_requires('Exec[init_restic_lab_repository]')
  end

  it do
    is_expected.to contain_file('/usr/local/sbin/lab-restic-retention')
      .with(owner: 'root', group: 'root', mode: '0755')
      .with_content(%r{forget "\$\{forget_args\[@\]\}"})
      .with_content(%r{--keep-daily 7})
      .with_content(%r{--keep-weekly 4})
      .with_content(%r{--keep-monthly 6})
      .with_content(%r{--keep-yearly 1})
      .with_content(%r{forget_args\+=\(--prune\)})
      .that_requires('Exec[init_restic_lab_repository]')
  end
end
