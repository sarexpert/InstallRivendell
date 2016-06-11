#!/bin/bash
# script to set up computer with Ubuntu Studio for Audio as audio Workstation, Rivendell workstation, or NetJack Master server
#
#   Exit on error or unreferenced environment value or failure of pipe
#
set -o pipefai
df=""  # timestamp date and time
closentpserver=""

#
#  First Part of Music network address
#
eth1adr="192.168.60." # First part of music network address
# ------------------------------------------------------------------------------
#  Script functions
#
# Test an IP address for validity:
# Usage:
#      valid_ip IP_ADDRESS
#      if [[ $? -eq 0 ]]; then echo good; else echo bad; fi
#   OR
#      if valid_ip IP_ADDRESS; then echo good; else echo bad; fi
#
function valid_ip()
{
    local  ip
    ip=$1
    local  state
    state=1

    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        OIFS=$IFS
        IFS='.'
        ip=($ip)
        IFS=$OIFS
        [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 \
            && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
        state=$?
    fi
    return "$state"
}
#  End of function valid_ip()
# ------------------------------------------------------------------
#  Remove Package function
#
#  usage: removepkg package1 [package2 package3 ...]
#
#
function removepkg() 
{
for pkg in "$@"
do
    if [[ $(dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null |grep -c "ok installed") -eq 1 ]] ; then {
    apt-get -yq remove --purge --auto-remove "$pkg" && echo "remove $pkg $(timestamp  $df)" | tee -a setupcomputer.log
}
fi
done
}
#   End of removepkg function
#  ---------------------------------------------
#
#  Timestamp function
#
#  usage:  timestamp FLAG
#      ex  timestamp "D"
#       01/02/15 | 20:22:12
#          timestamp ""
#       20:22:12
function timestamp() {
  local d1
  d1=$(date +%D)
  local dt
  dt=$(date +%T)
  local state
  if [[ -n $1 ]] ; then
       dt+=" | "$d1
  fi
  echo "$dt"
  state="0"
  return "$state"
}

#
#  End of Timestamp function
#  ----------------------------------------------------
#
#  Install package function
#
#  usage:  installpkg package1 [package 2 package3 ...]
function installpkg() {
for pkg in "$@"
do
    if [[ $(dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null |grep -c "ok installed") -eq 0 ]] ; then {
    apt-get -yq install "$pkg" && echo "install $pkg $(timestamp  $df)" | tee -a setupcomputer.log
}
fi
done
}

#
#  End of Installpkg function
# ---------------------------------------------------------
#
#
#   Test to see if script is compatible with installation
#
sess=$(dpkg -l |grep "ubuntustudio")
if [[ "$sess" == "" ]] ; then {
	zenity --error --text="This script is only for Ubuntu Studio installations. The distibution is not compatible - Exiting"     
	exit 1;
	}
fi
[[ $(id -u) -eq 0 ]] || { zenity --error --text="Script must be run as root ( ~$ sudo ./setupcomputer.sh) "; exit 1; }
#==========================================
printf "\033c"
cat << 'EOF'  
Congratulations! = Your computer will probably work on this script.

===UBUNTU STUDIO AUDIO APPLICATIONS ENHANCEMENT SCRIPT======
  *Configures and upgrades Jack2 Audio Connection Kit
  *Adds KXStudio interface to Jack
  *Prepares for NetJack
  *Rivendell workstation option sets up Rivendell with Jack
  *Server workstation sets up central server for multiple Rivendell workstations
	Rivendell radio automation
        Owncloud cloud file sharing to Rivendell
        Icecast2 streaming server
Warning! -- This script installs programs from private PPA repositories
This means that they come from "untrusted sources".  The programs work for me
and were OK when I used them, but there is no control over what the authors may 
do in the future.  This script should be used on a fresh Ubuntu Studio
installation to avoid unexpected interactions with other installed applications,
or previous adjustments to configuration.

This script is offered without warranty - use at your own risk.
Copyright 2015 Edward A. Schober - Creative Commons -attribution license for its use.
Please report problems or improvements for this script to: ted@schober.us

EOF
if ( ! $(zenity --question --text="Shall we proceed" )) ; then zenity --info --text="Terminated script on user command" ; exit
fi
printf "\033c"
#

#
#
if [ -e ~/setupcomputer.log ] ; then
   echo "Log file setupcomputer.log exists"
   if (  $(zenity --question --text="Delete this file for initial setup")) ; then
        rm ~/setupcomputer.log
        echo "file deleted"
        firstrun=true
    else
        firstrun=false
    fi
else
        firstrun=true
fi


#  Here we collect information about your installation
#
#  General Type of installation
#
        echo " Please note that a Jack Server includes a full Rivendell installation - Use standalone"
	ans=""
        title="Computer Purpose"
	while [ -z "$ans" ] ; do {
  	ans=$(zenity --list --title="$title" --radiolist  --column "Pick" --column "Use" false "Rivendell Network" false "Rivendell Standalone" false "Jack Net Server" false "Audio Workstation")
  	case $ans  in
     		"Audio Workstation" ) 
		svtype="Workstation"
        	rivendell=false
        	icecast2=false
        	butt=false
        	mariadb=false
        	owncloud="none"
                networking="none"
                removepulse=false
                disableapci=false
                stereotool=true
        	 ;;
     		"Jack Net Server")
        	svtype="Jack Server"
        	rivendell=true
        	icecast2=true
        	butt=true
        	mariadb=true
        	owncloud="server"
                networking="server"
                removepulse=true
                disableapci=true
                stereotool=true
		 ;;
    		"Rivendell Network" )
        	svtype="Rivendell Playout"
        	rivendell=true
        	icecast2=false
        	butt=false
        	mariadb=true           
        	owncloud="client"
                removepulse=true
                disableapci=true
                networking="client"
                stereotool=false
        	 ;;
                "Rivendell Standalone" )
                svtype="Rivendell Standalone"
        	rivendell=true
        	icecast2=false
        	butt=true
                mariadb=true
                owncloud="none"
                removepulse=true
                disableapci=true
                networking="none"
                stereotool=true
        	 ;;  
     		*) 
		svtype=""
        	ans=""
        	title="Try Again"
		;;
  	esac
  	}
	done
 	cp /etc/network/interfaces /etc/network/interfaces.orig
#
#  Select Stereotool Installation
#if [[ $stereotool = true ]] ; then 
       if ( ! $(zenity --question --no-wrap --title="StereoTool" --text="`printf "Stereotool is a powerful audio processor\nfor broadcast and noise reduction\nIt is available as shareware.\n\nInstall StereoTool?"`"))  ; then
            stereotool=false
       fi
fi  
ip=""
if [[ "$svtype" == "Rivendell Playout" ]] ; then 
# Set up music network address STATIC     
    adr=$eth1adr
    first=101
    last=110
    for ip in $(seq $first $last); do 
        ping -r -I eth0 -c 1 "$adr$ip"  >/dev/null
        if [ $? -gt 0 ] ; then break
        fi        
    done
    adr=$adr$ip
    cat << EOF
NetJack computers should have a static address on the Music Network and an unchanging
address on the Office Network, This script will set up the music network
automatically. 
EOF
    echo "Music network (eth1) set STATIC to $adr"
fi 
if [[ "$svtype" == "Jack Server" ]] ; then { 
	# Assemble address for music network eth1
	ip=1
       	adr="$eth1adr$ip"
	cat << EOF
NetJack computers should have a static address on the Music Network and an unchanging
address on the Office Network, This script will set up the music network
automatically, and will assume that user will set up either a static address on 
the office network or configure the office DHCP server to always provide the same address to eth0. 
EOF
    echo "Music network (eth1) set STATIC to $adr"
    }
fi

#  Main user name
#
ans=""
while [ -z "$ans" ] ; do
	ans=$(zenity --entry --title="User Name" --text="Enter the user name of the \"Owner\" of\n this computer (Not the Rivendell user)" --entry-text="$LOGNAME")
	user=$ans
done
ans=""
while [ -z "$ans" ] ; do
	ans=$(zenity --entry --title="Email Address" --text="Enter the email address to use for notifications")
	useremail=$ans
done
ans=""
#------------------------------------------------------------------------
#     Setting the current version of KXstudio by checking at 
#     http://kxstudio.linuxaudio.org/Repositories
#     Otherwise this script may not find KXstudio
kxver=""
firefox -new-tab http://kxstudio.linuxaudio.org/Repositories &
while [ -z "$kxver" ] ; do
    kxver=$(zenity --entry --title="KXstudio version" --text="set the current version of      KXstudio\n Enter the version number from the Debian/Ubuntu\n section at 'install it' in the browser \n  Otherwise this script may not find KXstudio" --entry-text="9.2.2")
done
#
#  Type of Uninterruptable Power supply  
#
title="UPS selector"
ups=$(zenity --list --title="$title" --radiolist  --column "Pick" --column "UPS type" false "APC" false "CyberPower" true "none")

if [ "$firstrun" = true ] ; then {
	cat << EOF
If serving as a NetJack server or Rivendell workstation this script assumes
two ethernet interfaces, eth1 (gigabit) for the music network and eth0 for 
the regular Network. The music network will be assigned static addresses
EOF
	echo "in the $eth1adr.0\24 segment."
        cat << EOF
 If you want to change these settings you must edit this file. The audio 
interfaces you wish to use should be installed. eth0 must be connected 
to the internet for updates. Any Rivendell workstations or Rivendell/NetJack
servers that have already been set up should be running with their eth1
interfaces connected to a network switch. 

EOF
}
fi
#  Root password for SQLserver
title="Database Password"
mariarootpw=$(zenity --entry  --title="$title"  --text="Enter a root password for the MariaDB database" --entry-text="fixit")
#
# Network Time Protocol
ans=''
ntplocal=""
title="NTP Server"
if [ "$svtype" == "Jack Server" ] ; then
   
    if ( ! $(zenity --question --title="$title" --text="Will this machine be the local NTP server? "))  ; then 
         ans=""
         while [ -z "$ans" ] ; do {
           msg=""
           if ( $(zenity --question --text="Use an NTP server on this network" )) ; then 
                ans=$(zenity --entry  --title="$title" --title="NTP Server" --text="Enter the IP of the local \n NTP server [nnn.nnn.nnn.nnn]" )
                if valid_ip "$ans" ; then 
                    ntplocal=$ans
                    echo "local time server is $ntplocal"
                else
                    ans=""
                    zenity --error  --title="$title" --text="Please enter again - Not a valid IP Address"
                fi
            fi
          }
          done  
      fi
else  #not jackserver
        if  ( $(zenity --question  --title="$title" --text="Does the network have a local NTP server")) ; then 
             ans=""
             while [ -z "$ans" ] ; do {
                 ans=$(zenity --entry  --title="$title" --title="Local NTP Server" --text='Enter the IP of the local \n time (NTP) server [nnn.nnn.nnn.nnn] ')
                 if valid_ip "$ans" ; then 
                        ntplocal=$ans
                        echo "local time server is $ntplocal"
                     else
                        ans=""
                        zenity --error  --title="$title" --text="Please enter again - Not a valid IP Address"
                     fi
                ho
              }
              done
           else
              echo "no local NTP server"    
           fi        
fi 
ans=""
#  Computer information
#
dn="$(hostname -A)"
ans=$(zenity --entry --title="Computer Domain" --text="Enter the domain of this computer" --entry-text="$dn " )
if [ ! -z "$ans" ] ; then
     dn="$ans"
fi
echo $dn
#   type of processor amd64 | i386 
proc="$(uname -m | grep 64 2>/dev/null)"
if [ -z "$proc" ] ; then 
    proc="i386"
    stproc=''
else 
    proc="amd64"
    stproc="_64"
fi
echo "Processor technology: $proc "

#
#  ============ Now we start doing stuff! ===========
#
#  Start a log
echo "Begin Install as $svtype $(timestamp $df)" > setupcomputer.log

#  Add Repositories
#
#  add KXStudio repository
#
wget "https://launchpad.net/~kxstudio-debian/+archive/kxstudio/+files/kxstudio-repos_$kxver~kxstudio1_all.deb"
dpkg -i "kxstudio-repos_$kxver~kxstudio1_all.deb" && echo "Install KXstudio repository $(timestamp $df)" > setupcomputer.log

#
#  Add Current OwnCloud Repository
#
if [[ ! "$owncloud" == "none" ]] ; then {
	add-apt-repository -y 'deb http://download.opensuse.org/repositories/isv:/ownCloud:/community/xUbuntu_14.04/ /' 
	wget -q 'http://download.opensuse.org/repositories/isv:/ownCloud:/community/xUbuntu_14.04/Release.key'
	apt-key add - < Release.key && echo "Add Owncloud repository $(timestamp $df)"  | tee -a setupcomputer.log
	rm Release.key ;
}
fi

#
#   current Rivendell Repository
#
if [ "$rivendell" = true ] ; then
	add-apt-repository -y 'deb http://debian.tryphon.eu trusty main contrib'
#	add-apt-repository 'deb-src http://debian.tryphon.eu trusty main contrib'
	wget -q http://debian.tryphon.eu/release.asc
	apt-key add - < release.asc && echo "Add Rivendell repository $(timestamp $df)" | tee -a setupcomputer.log
	rm release.asc
fi
#
#   Current icecast2 Repository
#
if [ "$icecast2" = true ] ; then
	add-apt-repository -y 'deb http://download.opensuse.org/repositories/multimedia:/xiph/xUbuntu_14.04/ /'
	wget -q 'http://download.opensuse.org/repositories/multimedia:/xiph/xUbuntu_14.04/Release.key'
	apt-key add - < Release.key && echo "Add Icecast2 repository $(timestamp $df)"  | tee -a setupcomputer.log
	rm Release.key
fi

#
#   current butt ppa
if [ "$butt" = true ] ; then
	add-apt-repository -y ppa:s-launchpad-7/butt && echo "Add butt repository $(timestamp $df)" | tee -a setupcomputer.log
fi
#
# ================== update upgrade (includes the new repositories) ===============
#
apt-get -q update
apt-get -yq dist-upgrade && echo "Update and Dist Upgrade  $(timestamp $df)" | tee -a setupcomputer.log
# Remove out of date files
apt-get -yq autoremove && echo "Autoremove unneeded packages $(timestamp $df)" | tee -a setupcomputer.log
apt-get -yq autoclean
echo "Apt upgrade done"
#
# Set interface values for eth1 to Static 
#  Need to fix this and change to SED	
#

grep "eth0" < /etc/network/interfaces > /dev/null
if [ ! "$ip" == "" ] && [ $? -eq 1 ] ; then 
   echo "Set eth0 to dhcp" 
   {
   echo "# The primary network interface"
   echo "auto eth0"
   echo "iface eth0 inet dhcp"
   }
fi
grep "eth1" < /etc/network/interfaces > /dev/null
if [ ! "$ip" == "" ] && [ $? -eq 1 ] ; then 
   echo "Set eth1 static IP  = $adr"
   {
   echo "# The music network interface"
   echo "auto eth1" 
   echo "iface eth1 inet static"
   echo "address $adr"
   echo "netmask 255.255.255.0"
   echo "gateway broadcast $eth1adr""1" 
   }  >> /etc/network/interfaces
fi
#
#
#   Disable Pulseaudio
#
if [ "$removepulse" = true ] ; then 
      cp /etc/pulse/client.conf  /etc/pulse/client.conf.orig
      sed -i 's/*autospawn = yes/ autospawn = no/' /etc/pulse/client.conf
      service pulseaudio stop
      echo "Disable pulseaudio $(timestamp $df)" | tee -a setupcomputer.log
fi
#
#   Trim SSD drive weekly
#
if ( hdparm -I /dev/sda | grep -q "TRIM supported" ) ; then
    sed -i 's/exec fstrim-all\s+$/exec fstrim-all --no-model-check/' /etc/cron.weekly/fstrim && echo "Weekly trim SSD drives if /dev/sda is one $(timestamp $df)" | tee -a setupcomputer.log
fi

#
# install tools 
#
#  Repository Management Tools
installpkg software-properties-common
#  etckeeper and git
if [ ! -e "/etc/etckeeper/etckeeper.conf" ] ; then {
	installpkg git-core etckeeper git-doc
        git config "--global user.name $user" 
        git config "--global user.email $useremail"
	if [[ ! -e  "/etc/etckeeper/etckeeper.conf.orig" ]] ; then {
                cp /etc/etckeeper/etckeeper.conf /etc/etckeeper/etckeeper.conf.orig
        	sed -i 's/#VCS="git"/VCS="git"/' /etc/etckeeper/etckeeper.conf 
        	echo " enable etckeeper to use git $(timestamp $df)" | tee -a setupcomputer.log
        	sed -i 's/VCS="bzr"/#VCS="bzr"/' /etc/etckeeper/etckeeper.conf 
        	echo " disable etckeeper to use bzr $(timestamp $df)" | tee -a setupcomputer.log
                /usr/bin/etckeeper init && echo "Initialize Etckeeper git repo $(timestamp $df)" | tee -a setupcomputer.log

                /usr/bin/etckeeper commit "Initial commit." && echo "Start Etckeeper with first commit $(timestamp $df)" | tee -a setupcomputer.log
	}
    	else
        	echo "/etc/etckeeper/etckeeper.conf.orig exists - no setup done" ;
    	fi;
}
else 
	echo "/etc/etckeeper/etckeeper.conf- etckeeper already installed $(timestamp $df)" | tee -a setupcomputer.log
fi
#  VIM
installpkg vim
# aptitude
installpkg aptitude
#  Large Volume Manager
installpkg system-config-lvm
#
# Install gksu (Graphical Super User)
#
installpkg gksu
#
# Install python utilities
#
installpkg python-software-properties build-essential debconf-utils python-dev libpcre3-dev libssl-dev python-pip 
#
# Install ssmtp command line mail transport agent
#
installpkg ssmtp
echo 'edit /etc/ssmtp/ssmtp.conf to add system specific mail configuration'
# to hide password from prying eyes add yourself to ssmtp group
vim /etc/ssmtp/ssmtp.conf
groupadd ssmtp
chown :ssmtp /etc/ssmtp/ssmtp.conf
chmod 640 /etc/ssmpt/ssmtp.conf
chmod g+s /usr/bin/ssmtp
#
#  Remove Network Manager if networked system
#      (flakey with static IP - Needed for WiFi)
#
if [[ ! networking == "none" ]] ; then
    removepkg network-manager 
fi

#
# install ntp
#
installpkg ntp ntp-simple ntpd
if [ -e "/etc/ntp.conf" ] && [[ ! -e  "/etc/ntp.conf.orig" ]] ; then {
        cp /etc/ntp.conf /etc/ntp.conf.orig
        if [[ ! $closentpserver = "" ]] ; then             
              closentpserver=$closentpserver"\n"
              sed -i "0,/^ *server /s/^ *server /&  $closentpserver& /" /etc/ntp.conf && echo "Added NTP server $closentpserver $(timestamp $df)"  | tee -a setupcomputer.log   
	fi        
        if [[ ! "$closentpserver" = "" ]] ; then
              echo "restrict $closentpserver mask 255.255.255.255 nomodify notrap noquery" >> /etc/ntp.conf &&  echo "Opened Restriction from $closentpserver $(timestamp $df)" | tee -a setupcomputer.log
              closentpserver=$closentpserver"\n"
              sed -i "0,/^ *server /s/^ *server /&  $closentpserver& /" /etc/ntp.conf && echo "Added NTP server $closentpserver $(timestamp $df)" | tee -a setupcomputer.log
	fi
        
}
fi
service ntp restart
# 
#  Install SSH
#
installpkg openssh-server
if [ -e "/etc/ssh/sshd_config" ] && [[ ! -e  "/etc/ssh/sshd_config.orig" ]] ; then {
     cp /etc/ssh/sshd_config /etc/ssh/sshd_config.orig ;
}
fi
/etc/init.d/ssh restart
#
#  Install VNC server and client
#
installpkg x11vnc
# setup x11vnc password
echo "Enter Password for x11vnc (Don't make it trivial!)"
x11vnc -storepasswd
#
#  Install UPS Manager
#
if [[ ! "$ups" == '' ]] ; then {

	case $ups in
	APC) installpkg apcupsd
        if [[ ! -e /etc/default/apcupsd.orig ]] ; then
          cp /etc/default/apcupsd  /etc/default/apcupsd.orig
        fi
        sed -i 's/ISCONFIGURED=no/ISCONFIGURED=yes/' /etc/default/apcupsd 
	;;
	CyberPower) wget -q 'http://www.cyberpowersystems.com/software/powerpanel_1.3.2_'$proc'.deb'
	dpkg -i 'powerpanel_1.3.2_'$proc'.deb'         
        rm powerpanel*.deb
        ;;
        *) echo "No UPS application installed" | tee -a setupcomputer.log
	;;
esac
}
fi
#   Turn off Automatic Updates (use apt-get)
#
if [[ ! -e /etc/apt/apt.conf.d/10periodic.orig ]] ; then
      cp /etc/apt/apt.conf.d/10periodic /etc/apt/apt.conf.d/10periodic.orig
      sed -i 's/APT::Periodic::Update-Package-Lists "1";/APT::Periodic::Update-Package-Lists "0";/' /etc/apt/apt.conf.d/10periodic
      echo "Disable automatic updates $(timestamp $df)"  | tee -a setupcomputer.log
fi
#
#   Turn off APCI (Power management) 
#
if [ "$disableapci" = true ] ; then
    if [[ ! -e /etc/default/grub.orig ]] ; then
      cp /etc/default/grub /etc/default/grub.orig
    fi
    sed -i 's/GRUB_TIMEOUT=10/GRUB_TIMEOUT=0/' /etc/default/grub
    sed -i 's/\(GRUB_CMDLINE_LINUX_DEFAULT=\)*/\1'="quiet splash apci=off apm=off"'/' /etc/default/grub
    update-grub && echo "Disable apci $(timestamp $df)"  | tee -a setupcomputer.log
fi
#
# Install MariaDB
#
if [ "$mariadb" = true ] ; then { 
        # Remove MySQL
        service mysql stop
        removepkg mysql-server mysql-client mysql-common
	#  Install MariaDB dropin replacement for MySQL
	installpkg mariadb-server mariadb-client 
        mysql_secure_installation 
	mysql -v -u root -p "$mariarootpw" && echo "Install MariaDB with root password of $mariarootpw $(timestamp $df)" | tee -a setupcomputer.log
        service mysql start
}
fi
#
#  install phpMyadmin
#
	installpkg phpmyadmin 
	ln -s /usr/share/phpmyadmin/ /var/www/html
	service apache restart && echo "Restart apache webserver $(timestamp $df)" | tee -a setupcomputer.log
	etckeeper commit "installed LEMP server";
#
#   Install VirtualBox
#
if [ "$networking" == "server" ] ; then
        installpkg virtualbox-qt virtualbox-guest-utils
fi
#
#  Install network file system
#
if [ "$networking" == "server" ] ; then
        installpkg nfs-kernel-server
fi
if [ "$networking" == "client" ] ; then
        installpkg nfs-common
fi
#
#   Install OwnCloud Cloud server
#
if [ "$owncloud" == "server" ] ; then
	installpkg owncloud
	ownclouddb="owncloud"
	ownclouddbuser="owncloud"
	ownclouddbpw="bjx3!3!"
	installpkg owncloud
	mysql -u root -p "$mariarootpw" -e << EOF
	CREATE DATABASE $ownclouddb ;
	GRANT ALL ON $ownclouddb".* to "$ownclouddbuser@'localhost' IDENTIFIED BY $ownclouddbpw ;
	exit
EOF
echo "Initialized database $ownclouddb with user $ownclouddbuser and pw $ownclouddbpw"
fi
#   Install OwnCloud Cloud client
#
if [[ ! "$owncloud" == "none" ]] ; then
	installpkg owncloud-client
        echo "Install owncloud client"
fi
#
#   Install CACert root certificate
#
if [[ ! -e /usr/share/ca-certificates/cacert.org ]] ; then 
        mkdir /usr/local/share/ca-certificates/cacert.org
fi
wget -P /usr/local/share/ca-certificates/cacert.org http://www.cacert.org/certs/root.crt http://www.cacert.org/certs/class3.crt
update-ca-certificates && echo "Install CAcert root certificates $(timestamp $df)" | tee -a setupcomputer.log

#
# Install extras for Jack
#
installpkg vlc vlc-plugin-jack
installpkg liquidsoap  jackmeter silentjack jmeters volti 
#
#  Install StereoTool audio Processor
#
if [ stereotool = true ] ; then
   if [ ! -f /usr/bin/stereo_tool_gui ] then
      wget -q 'http://www.stereotool.com/download/stereo_tool_gui$stproc'
      chmod a+x 'stereo_tool_gui$stproc'
      chown 'root:root' 'stereo_tool_gui$stproc'
      mv "stereo_tool_gui$stproc /usr/bin/stereo_tool_gui"
      echo "Installed StereoTool to /usr/bin $(timestamp  $df)" | tee -a setupcomputer.log
   fi
fi

#
# Install / update KXStudio
#
# Remove any old kxstudio stuff
if [ -f "/var/kxstudio/*" ] ; then {
	rm -f "/var/kxstudio/*"
}
fi

installpkg cadence  
#
#  Install Wine from KXstudio repository
#
installpkg kxstudio-meta-wine

#
#   install butt
#
if [ "$butt" = true ] ; then 
	if [ ! -e "$HOME/butt1" ] ; then 
            cp "$HOME/butt1 $HOME/butt1.orig" 
        fi
        installpkg butt
fi
#
#  Install Icecast2
#
if [ "$icecast2" = true ] ; then 
        installpkg icecast2
fi
#
#   install rivendell	 
#
if [ "$rivendell" = true ] ; then {
   if [ "$networking" == "server" ] ; then {
     if [ ! -e /etc/mysql/my.cnf.dist ] ; then 
         cp /etc/mysql/my.cnf /etc/mysql/my.cnf.dist 
     fi
     sed -i 's/127.0.0.1/0.0.0.0/' /etc/mysql/my.cnf && echo "allow connections to mysql from other hosts"
     service mysql restart && echo "Configure mysql [mariadb] for remote access $(timestamp $df)" | tee -a setupcomputer.log
     installpkg rivendell-server
   }
   fi
  installpkg rivendell
#    Add the rivendell user "rduser"
   /usr/bin/id 'rduser' > /dev/null 2>&1
   if [ $? -eq 0 ] ; then
       echo rduser exists
   else {
       adduser --disabled-password --gecos "" rduser && adduser rduser audio  && adduser rduser rivendell && echo "Added rduser and joined audio and rivendell groups $(timestamp $df)" | tee -a setupcomputer.log;
       }
   fi
#
#    Adjust setups for rduser 
#
   if [ -d ../rduser ] ; then {
#    rduser desktop and menus
      mkdir -p /home/rduser/.config/menus
#cp $prefix/etc/xdg/menus/xfce-applications.menu /home/rduser/.config/menus
      mkdir -p /home/rduser/.local/share/applications
      cp /usr/share/applications/xfce4-run.desktop /home/rduser/.local/share/applications/xfce4-run.desktop
      echo "Setup separate desktop for rduser $(timestamp  $df)" | tee -a setupcomputer.log
#    Add rivendell scripts to rduser home folder
      wget  -q "https://tecwhisperer.com/wp-content/uploads/2015/04/rdscripts.tar.gz"
      tar -zxvf rdscripts.tar.gz && chmod +x rdscripts/*.sh && cp -r rdscripts ../rduser/ && rm rdscripts.tar.gz && rm -r rdscripts &&    echo "Added Rdscripts to rduser folder $(timestamp  $df)" | tee -a setupcomputer.log
      }
      fi

#   Add Jack Configuration and CAE to /etc/rd.conf
      if [ ! -e /etc/rd.conf ] ; then
        cp /etc/rd.conf /etc/rd.conf.dist
      fi
      grep "[JackSession]" < /etc/rd.conf > /dev/null
      if [ $? -eq 1 ] ; then 
          echo << 'EOF' >> /etc/rd.conf
[JackSession]
Source1=rivendell_0:playout_0L
Destination1=system:playback_1
Source2=rivendell_0:playout_0R
Destination2=system:playback_2
Source3=system:capture_1
Destination3=rivendell_0:record_0L
Source4=system:capture_2
Destination4=rivendell_0:record_0R

'EOF'
      echo "/etc/rd.conf added [JackSession] configuration $(timestamp $df)" | tee -a setupcomputer.log
      fi
#   Add Jack Configuration and CAE to /etc/rd.conf
     if [ ! -e /etc/rd.conf ] ; then
          cp /etc/rd.conf /etc/rd.conf.dist
     fi
     grep "[JackSession]" < /etc/rd.conf > /dev/null
     if [ $? -eq 0 ] ; then 
          cat <<'EOF'  >> /etc/rd.conf
#
[JackSession]
Source1=rivendell_0:playout_0L
Destination1=system:playback_1
Source2=rivendell_0:playout_0R
Destination2=system:playback_2
Source3=system:capture_1
Destination3=rivendell_0:record_0L
Source4=system:capture_2
Destination4=rivendell_0:record_0R
EOF
         echo "/etc/rd.conf added [JackSession] configuration $(timestamp $df)" | tee -a setupcomputer.log
    fi
    grep "[Cae]" < /etc/rd.conf > /dev/null
    if [  $? -eq 0 ] ; then 
         cat <<'EOF'  >> /etc/rd.conf
#
[Cae]
# AudioRoot can be changed if your music is stored in another place
#
AudioRoot=/var/snd
AudioExtension=wav
AllowNonstandardRates=Yes
EOF
         echo "/etc/rd.conf added [Cae] section $(timestamp $df)" | tee -a setupcomputer.log
    fi 
#    Set samplerate to 48000 in /etc/rd.conf
    sed -i 's/SampleRate=44100/SampleRate=48000/' /etc/rd.conf && echo "/etc/rd.conf edited for sample rate $(timestamp $df)" | tee -a setupcomputer.log
    }
fi 
# End of Rivendell installation 
#
#
# Remove out of date files
apt-get -yq autoremove && echo "Autoremoved new out of date files $(timestamp $df)"  | tee -a setupcomputer.log
echo "Automated setup complete please reboot computer"
