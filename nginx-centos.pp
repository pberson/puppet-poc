#title           :nginx-centos.pp
#description     :This a Puppet manifest file for install nginx
#author		 :Peter Berson
#date            :20161009
#version         :0.1    
#usage		 :puppet apply nginx-centos.pp
#notes           :requires puppetlabs-vcsrepo, puppetlabs-stdliba modules
#==============================================================================
$osver = split($::operatingsystemrelease, '[.]')
$osname = downcase($::operatingsystem)
$httpd_port = 8000

if $osname == 'centos' {
  Yumrepo <| |> -> Package <| provider != 'rpm' |>
  yumrepo { "nginx-repo":
        baseurl => "http://nginx.org/packages/$osname/${osver[0]}/\$basearch/",
        descr => "Nginx official release packages",
        enabled => 1,
        gpgcheck => 0,
        priority => 1,
  }
  package { "nginx": 
        ensure => installed, 
        require => Yumrepo["nginx-repo"] 
  }
}

package { "git":
    ensure => installed
}

package { 'policycoreutils-python':
    ensure => installed,
}


if ($operatingsystemmajrelease + 0)  <= 6 {
   exec { 'iptables':
      command => "iptables -I INPUT 1 -p tcp -m multiport --ports ${httpd_port} -m comment --comment 'Custom HTTP Web Host' -j ACCEPT && iptables-save > /etc/sysconfig/iptables",
      path => "/sbin",
      refreshonly => true,
      subscribe => Package['nginx'],
   }
   service { 'iptables':
      ensure => running,
      enable => true,
      hasrestart => true,
      subscribe => Exec['iptables'],
   }
}
elsif ($operatingsystemmajrelease + 0) == 7 {
    package { "firewalld": 
      ensure => installed, 
    }

   service { 'firewalld':
      ensure => running,
      enable => true,
      hasrestart => true,
#      subscribe => Exec['firewall-cmd'],
   }
   exec { 'firewall-cmd':
      command => "firewall-cmd --zone=public --add-port=${httpd_port}/tcp --permanent; firewall-cmd --reload", 
      path => "/usr/bin/",
#      refreshonly => true,
      onlyif => ["test `firewall-cmd --zone=public --query-port=${httpd_port}/tcp | grep no`"],
      require => Package['firewalld'],
#      subscribe => Package['nginx'],
#      notify => Service['firewalld'],
   }
}

# Handle selinux and delete port if it’s there
exec { 'semanage-port-delete':
   command => "semanage port -d -t http_port_t -p tcp ${httpd_port}",
   path => "/usr/sbin",
   require => Package['policycoreutils-python'],
   before => Exec['semanage-port'],
   refreshonly => true,
}

# Handle selinux modifying http_port_t to add defined httpd_port

exec { 'semanage-port':
   command => "semanage port -m -t http_port_t -p tcp ${httpd_port}",
   path => "/usr/sbin",
   require => Package['policycoreutils-python'],
   before => Service['nginx'],
   subscribe => Package['nginx'],
   refreshonly => true,
} 

service { "nginx":
    require => Package["nginx"],
    ensure => running,
    enable => true
}

file { "/etc/nginx/conf.d/default.conf":
    require => Package["nginx"],
    ensure  => absent,
    notify  => Service["nginx"]
}
# Create directory for site
file { "/www":
    ensure => "directory"
}
# Pull content from Git repo
vcsrepo { '/www':
  require => Package["git"],
  force => true,
  ensure   => latest,
  provider => git,
  source   => 'https://github.com/pberson/test-website',
}

file { "/etc/nginx/conf.d/puppet-tech.conf":
    require => [
        Package["nginx"],
        File["/www"]
    ],
    ensure => "file",
    content => 
        "server {
            listen ${httpd_port} default_server;
            server_name _;
            location / { root /www; }
        }",
    notify => Service["nginx"]
}


