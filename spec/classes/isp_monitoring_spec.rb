require 'spec_helper'

describe 'isp_monitoring' do
  it { is_expected.to compile.with_all_deps }

  it { is_expected.to contain_package('prometheus-node-exporter').with_ensure('installed') }

  it do
    is_expected.to contain_file('/var/lib/node_exporter')
      .with(ensure: 'directory', owner: 'root', group: 'root', mode: '0755')
      .that_requires('Package[prometheus-node-exporter]')
  end

  it do
    is_expected.to contain_file('/var/lib/node_exporter/textfile_collector')
      .with(ensure: 'directory', owner: 'root', group: 'root', mode: '0755')
      .that_requires('File[/var/lib/node_exporter]')
  end

  it do
    is_expected.to contain_file('/etc/prometheus')
      .with(ensure: 'directory', owner: 'root', group: 'root', mode: '0755')
  end

  it do
    is_expected.to contain_file('/etc/prometheus/rules')
      .with(ensure: 'directory', owner: 'root', group: 'root', mode: '0755')
      .that_requires('File[/etc/prometheus]')
  end

  it do
    is_expected.to contain_file('/etc/default/prometheus-node-exporter')
      .with(owner: 'root', group: 'root', mode: '0644')
      .with_content(%r{--web\.listen-address=0\.0\.0\.0:9100})
      .with_content(%r{--collector\.textfile\.directory=/var/lib/node_exporter/textfile_collector})
      .that_requires('Package[prometheus-node-exporter]')
      .that_notifies('Service[prometheus-node-exporter]')
  end

  it do
    is_expected.to contain_file('/usr/local/sbin/lab-monitoring-check')
      .with(owner: 'root', group: 'root', mode: '0755')
      .with_content(%r{puppet_lab_service_up\{service="named"\}})
      .with_content(%r{puppet_lab_tcp_check_up\{name="submission"})
      .with_content(%r{puppet_lab_dns_authoritative_up})
      .with_content(%r{puppet_lab_backup_repository_ok})
      .that_requires('File[/var/lib/node_exporter/textfile_collector]')
  end

  it do
    is_expected.to contain_file('/usr/local/sbin/lab-monitoring-health')
      .with(owner: 'root', group: 'root', mode: '0755')
      .with_content(%r{CRITICAL - lab-monitoring-check failed})
      .with_content(%r{puppet_lab_service_up})
      .with_content(%r{puppet_lab_tcp_check_up})
      .with_content(%r{OK - lab monitoring metrics healthy})
      .that_requires('File[/usr/local/sbin/lab-monitoring-check]')
  end

  it do
    is_expected.to contain_file('/etc/prometheus/rules/puppet-lab-alerts.yml')
      .with(owner: 'root', group: 'root', mode: '0644')
      .with_content(%r{alert: PuppetLabMonitoringCheckStale})
      .with_content(%r{expr: time\(\) - puppet_lab_check_timestamp_seconds > 300})
      .with_content(%r{alert: PuppetLabServiceDown})
      .with_content(%r{alert: PuppetLabTCPCheckFailed})
      .with_content(%r{alert: PuppetLabDNSAuthoritativeFailed})
      .with_content(%r{alert: PuppetLabBackupRepositoryFailed})
      .that_requires('File[/etc/prometheus/rules]')
  end

  it do
    is_expected.to contain_exec('write_initial_puppet_lab_metrics')
      .with_command('/usr/local/sbin/lab-monitoring-check')
      .with_refreshonly(true)
      .that_subscribes_to('File[/usr/local/sbin/lab-monitoring-check]')
  end

  it { is_expected.to contain_service('prometheus-node-exporter').with(ensure: 'running', enable: true) }
end
