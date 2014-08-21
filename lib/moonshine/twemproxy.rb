module Moonshine::Twemproxy
  
  def self.included(manifest)
    manifest.configure :twemproxy => {}

    defaults = {
      :version => '0.3.0',
      :listen => '127.0.0.1:6379',
      :servers => [],
      :redis => true,
      :hash => "fnv1a_64",
      :distribution => "ketama",
      :auto_eject_hosts => true,
      :server_retry_timeout => 30000,
      :server_failure_limit => 3,
      :timeout => 400
    }

    if manifest.configuration[:twemproxy]
      manifest.configuration[:twemproxy].each do |k,v|
        defaults[k.to_sym] = v
      end
    end

    manifest.configure :twemproxy => defaults
  end

  def twemproxy
    recipe :twemproxy_package
    recipe :twemproxy_user
    recipe :twemproxy_config
    recipe :twemproxy_service
    recipe :twemcheck
  end

  def twemproxy_package
    download_dir = "/usr/local/src"
    version = configuration[:twemproxy][:version]
    package_name = "nutcracker-#{version}"
    package_url = "https://twemproxy.googlecode.com/files/#{package_name}.tar.gz"
    
    
    package 'wget', :ensure => :installed
    
    file download_dir,
    :ensure => :directory
    
    exec "download twemproxy",
    :command => "wget #{package_url}",
    :require => [package('wget'), file(download_dir)],
    :cwd => download_dir,
    :creates => "#{download_dir}/#{package_name}.tar.gz"
        
    exec 'untar twemproxy',
    :command => "tar zxvf #{package_name}.tar.gz",
    :require => [exec('download twemproxy')],
    :cwd => download_dir,
    :creates => "#{download_dir}/#{package_name}"
    
    exec 'install twemproxy',
    :command => "/bin/sh configure && make && make install",
    :user => 'root',
    :require => [exec('untar twemproxy')],
    :cwd => "/usr/local/src/#{package_name}",
    :notify => service("twemproxy"),
    :unless => "test -f /usr/local/sbin/nutcracker && test -f /usr/local/src/nutcracker_version.txt && cat /usr/local/src/nutcracker_version.txt | grep #{version}"
    
    file "/usr/local/src/nutcracker_version.txt",
    :content => configuration[:twemproxy][:version],
    :require => [exec("install twemproxy")],
    :owner => 'root',
    :mode => '755'
    
  end

  def twemcheck
    package 'xinetd', :ensure => :installed
    
    service 'xinetd',
      :ensure => :running,
      :require => package('xinetd')
      
    file '/etc/xinetd.d/twemcheck',
      :content => template(File.join(File.dirname(__FILE__), '..', '..', 'templates', 'twemcheck.xinetd.erb')),
      :ensure => :present,
      :owner => "root",
      :require => package("xinetd"),
      :notify => service('xinetd')
      
    file '/usr/local/bin/twemcheck',
      :content => template(File.join(File.dirname(__FILE__), '..', '..', 'templates', 'twemcheck.erb')),
      :ensure => :present,
      :owner => configuration[:user],
      :mode => '755',
      :require => package('xinetd'),
      :notify => service('xinetd')
  end

  def twemproxy_user
    group 'twemproxy',
    :ensure => :present
    
    user 'twemproxy',
    :gid => 'twemproxy',
    :comment => 'twemproxy server',
    :home => '/home/twemproxy',
    :shell => '/bin/false',
    :require => [group('twemproxy')]
  end

  def twemproxy_config    
    file "/etc/twemproxy",
    :ensure => :directory,
    :owner => 'twemproxy'
    
    config = {'alpha' => nil}
    
    alpha_config = configuration[:twemproxy].clone
    alpha_config.delete :version
    
    config['alpha'] = alpha_config
    
    file "/etc/twemproxy/nutcracker.yml",
    :content => template(File.join(File.dirname(__FILE__), '..', '..', 'templates', "nutcracker.yml.erb")),
    :ensure => :present,
    :require => [file("/etc/twemproxy"), exec('install twemproxy'), user('twemproxy')],
    :notify => service("twemproxy")
    
    file "/var/log/twemproxy",
    :ensure => :directory,
    :owner => 'twemproxy'
    
    file "/var/run/twemproxy",
    :ensure => :directory,
    :owner => 'twemproxy'
  end

  def twemproxy_service
    file "/etc/init/twemproxy.conf",
    :ensure => :present,
    :content => template(File.join(File.dirname(__FILE__), '..', '..', 'templates', "twemproxy_upstart.conf.erb")),
    :require => [file("/etc/twemproxy/nutcracker.yml"), user('twemproxy'), file("/var/run/twemproxy"), file("/var/log/twemproxy")],
    :owner => 'root',
    :mode => '644'
    
    service 'twemproxy',
    :provider => "upstart",
    :ensure => :running,
    :require => [file('/etc/init/twemproxy.conf')]
  end
end