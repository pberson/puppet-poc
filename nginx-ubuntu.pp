#title           :nginx-ubuntu.pp
#description     :This a Puppet manifest file for install nginx
#author		 :Peter Berson
#date            :20161009
#version         :0.1    
#usage		 :puppet apply nginx-ubuntu.pp
#notes           :requires puppetlabs-vcsrepo, puppetlabs-stdliba modules
#==============================================================================
$httpd_port = 8000
package { "nginx":
    ensure => installed
}

package { "git":
    ensure => installed
}

service { "nginx":
    require => Package["nginx"],
    ensure => running,
    enable => true
}

file { "/etc/nginx/sites-enabled/default":
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
  revision => 'master'
}

file { "/etc/nginx/sites-available/puppet-tech":
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
file { "/etc/nginx/sites-enabled/puppet-tech":
    require => File["/etc/nginx/sites-available/puppet-tech"],
    ensure => "link",
    target => "/etc/nginx/sites-available/puppet-tech",
    notify => Service["nginx"]
}
