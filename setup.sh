#!/bin/bash
#title           :setup.sh
#description     :This script will install Puppet and required Puppet modules and run PP_FILE
#author		 :Peter Berson
#date            :20161009
#version         :0.1    
#usage		 :sudu ./setup.sh
#notes           :make sure it is executable permission and run as root or sudo
#notes           :Tested with CentOS 6,7 and Ubuntu 15 and 16
#==============================================================================

dist=""
dist_rel=""
PP_FILE=nginx-OSNAME.pp
PUPPET=N
PUPPET_LAB_PATH=/opt/puppetlabs/bin
MODS=( puppetlabs-vcsrepo puppetlabs-stdlib )
MODS_NEEDED=()
MODS_INSTALLED=N
CENT_SRC=https://yum.puppetlabs.com/puppetlabs-release-pc1-el-MAJOR.noarch.rpm

SCRIPT_DIR=$(dirname "$0")

function check_puppet()
{
  if ! [ -x "$(command -v puppet)" ]
    then
	echo "puppet is not found on path"
	if ! [ -x "$(command -v $PUPPET_LAB_PATH/puppet)" ]
	then
	    echo "puppet is not found at $PUPPET_LAB_PATH"
	    return 0
	else
	    export PATH=$PUPPET_LAB_PATH:$PATH
	    echo "Setting Path:" $PATH
	fi   
  fi  
  #echo "Checking if Puppet is installed."
  puppet_ver=`puppet agent --version`
  if [ $? -eq 0 ]
  then
     PUPPET=Y
     for i in "${MODS[@]}"
     do
	echo "Checking if needed Puppet Modules are installed" $i
     	if puppet module list | grep -q $i 
     	then
	   echo "Found $i"
	else
	   MODS_NEEDED+=($i)	
     	fi
     done
     if [ ${#MODS_NEEDED[@]} -eq 0 ] 
     then
	MODS_INSTALLED=Y 
     fi
   fi
}

function apply_manifest()
{
   osFile=$(echo $PP_FILE | sed "s#OSNAME#$dist#g")
   osFile="$SCRIPT_DIR/$osFile"
   if [ -f $osFile ]
   then
      echo "Applying puppet manifest file: " $osFile
      puppet apply $osFile
      if [ ! $? -eq 0 ]
      then
         echo "puppet apply $osFile failed return code $?"
         exit 1
      else
	 echo "Puppet apply succeeded !"
      fi
   else
      dir=$(`pwd`)
      echo "Could not find Puppet manifest file: $osFile here $dir exiting"
      exit 1
   fi
}

########################
# Beging Here
#######################
#Check to see if user is root or sudo
if [[ $(id -u) -ne 0 ]] 
then 
   echo "Please run as root or with sudo exiting !!" 
   exit 1 
fi



echo "Determining OS ..."
if [ -f /etc/redhat-release ]
then
  dist=`cat /etc/redhat-release | awk -F " " '{print $1}'`
  # filed on CentOS 6
  #dist_rel=`cat /etc/redhat-release | awk -F " " '{print $4}'`
  # works better but could be imporoved 
  dist_rel=`cat /etc/redhat-release | grep -o '[0-9]\.[0-9]'`
fi

if [ -f /etc/lsb-release ]
then
   dist=`grep DISTRIB_ID /etc/lsb-release | awk -F '=' '{print $2}'`
   dist_rel=`grep DISTRIB_RELEASE /etc/lsb-release | awk -F '=' '{print $2}'`
   #apt-get update
fi

echo "Decteded OS = $dist and Release $dist_rel"
dist=$(echo $dist | tr '[:upper:]' '[:lower:]')

case $dist in
	"ubuntu") 
        	check_puppet
        	if [ "$PUPPET" == "N" ]
        	then
		   apt-get update
		   apt-get -y install puppet
		   check_puppet
		fi
		;;		
	"centos")
		check_puppet
		major=$(echo $dist_rel | cut -d. -f1)
		srcurl=$(echo $CENT_SRC | sed "s#MAJOR#$major#g")
        	if [ "$PUPPET" == "N" ]
        	then
		   rpm -Uvh $srcurl
		   yum -y install puppet
		   check_puppet
		fi
		;;
	*)
		echo "Unsupported Linux distrubtion " $dist
		exit 1
esac
 
if [ "$PUPPET" == "Y" ]
then 
   if [ "$MODS_INSTALLED" == "N" ]
   then
     for i in "${MODS_NEEDED[@]}"
     do
        echo "Installing " $i
	puppet module install $i
     done
     #empty array and recheck
     unset MODS_NEEDED
     check_puppet
   fi
fi

if [ "$PUPPET" == "Y" ] && [ "$MODS_INSTALLED" == "Y" ]
then
  apply_manifest 
else
  echo "Puppet or puppet Modiles VCS failed to install properly exiting ..."
  exit 1
fi

exit 0
