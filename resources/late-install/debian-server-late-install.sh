#!/usr/bin/env bash

#######################################################################################################
#
# Zack's - Debian Server Preseed - Late Install script 
# Version: 1.0
#
# This is a late-install script intended to run along with kvm-debian-server-unattended script.
# Do not run as a standalone script as it may break your system.
#
# © 2023 Zack's. All rights reserved.
#
#######################################################################################################

# Get release codename and version
OS_CODENAME=$(grep VERSION_CODENAME /etc/os-release | awk -F '=' '{print $2}')
OS_VERSION=$(grep VERSION_ID /etc/os-release | awk -F '=' '{print $2}' | tr -d '"')

# Download and initialize preseed
curl -Sso /tmp/debian-initial-customization.preseed \
https://raw.githubusercontent.com/zjagust/debian-server-initial-customization/main/preseed/debian-initial-customization.preseed
debconf-set-selections /tmp/debian-initial-customization.preseed

# Purge default sources.list
echo -n > /etc/apt/sources.list

# Set sources.list per Debian version
if [[ "$OS_VERSION" -ge "12" ]]
then
echo -e "# Main Repos
deb http://deb.debian.org/debian $OS_CODENAME main contrib non-free non-free-firmware
deb http://deb.debian.org/debian-security/ $OS_CODENAME-security main contrib non-free non-free-firmware
deb http://deb.debian.org/debian $OS_CODENAME-updates main contrib non-free non-free-firmware
# Sources - enable only when needed
#deb-src http://deb.debian.org/debian $OS_CODENAME main
#deb-src http://deb.debian.org/debian-security/ $OS_CODENAME-security main
#deb-src http://deb.debian.org/debian $OS_CODENAME-updates main
# Backports - For software like Git, Redis, etc.
deb http://deb.debian.org/debian $OS_CODENAME-backports main contrib non-free non-free-firmware" > /etc/apt/sources.list
else
echo -e "# Main Repos
deb http://deb.debian.org/debian $OS_CODENAME main contrib non-free
deb http://deb.debian.org/debian-security/ $OS_CODENAME-security main contrib non-free
deb http://deb.debian.org/debian $OS_CODENAME-updates main contrib non-free
# Sources - enable only when needed
#deb-src http://deb.debian.org/debian $OS_CODENAME main
#deb-src http://deb.debian.org/debian-security/ $OS_CODENAME-security main
#deb-src http://deb.debian.org/debian $OS_CODENAME-updates main
# Backports - For software like Git, Redis, etc.
deb http://deb.debian.org/debian $OS_CODENAME-backports main contrib non-free" > /etc/apt/sources.list
fi

# Update repositories
apt update

# Set boot verbosity
sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="quiet"/GRUB_CMDLINE_LINUX_DEFAULT=""/g' /etc/default/grub
# Enforce legacy interfaces names
sed -i 's/GRUB_CMDLINE_LINUX=""/GRUB_CMDLINE_LINUX="net.ifnames=0 biosdevname=0"/g' /etc/default/grub
# Update GRUB
update-grub

# Export and set LC_MESSAGES
export LC_MESSAGES=POSIX
export LC_TIME=C.UTF-8
update-locale "LC_MESSAGES=POSIX"
update-locale "LC_TIME=C.UTF-8"
locale-gen

# Get current interface name
INTERFACE_CURRENT=$(ip a | grep "2: " | awk '{print $2;}' | cut -d: -f1)
# Set interface name
sed -i "s/$INTERFACE_CURRENT/eth0/" /etc/network/interfaces

# Reconfigure debconf - minimal details
echo -e "debconf debconf/frontend select Noninteractive\ndebconf debconf/priority select critical" | debconf-set-selections

# Install required software for repo setup
apt install -y --no-install-recommends curl gnupg2 ca-certificates
	
# Set Sysdig repo key
curl -sS https://download.sysdig.com/DRAIOS-GPG-KEY.public | gpg --dearmor | tee /usr/share/keyrings/draios.gpg
	
# Define Sysdig repo source file
curl -sSo /etc/apt/sources.list.d/draios.list https://download.sysdig.com/stable/deb/draios.list
sed -i "0,/deb/ s/deb/& [signed-by=\/usr\/share\/keyrings\/draios.gpg]/" /etc/apt/sources.list.d/draios.list
	
# Update APT
apt update

# Install Aptitude
apt install --no-install-recommends -y aptitude apt-transport-https dirmngr
# Update repos with Aptitude
aptitude update -q2
# Forget new packages
aptitude forget-new
# Perform full system upgrade
aptitude full-upgrade --purge-unused -y
# Set aptitude configuration
mkdir /root/.aptitude
touch /root/.aptitude/config
cat <<-EOF > /root/.aptitude/config
aptitude "";
aptitude::Delete-Unused-Pattern "";
aptitude::UI "";
aptitude::UI::Advance-On-Action "true";
EOF

# Install standard software packages
aptitude install -R -y busybox_ bash-completion bind9-host busybox-static dnsutils dosfstools \
friendly-recovery ftp fuse geoip-database groff-base hdparm info install-info iputils-tracepath \
lshw lsof ltrace man-db manpages mlocate mtr-tiny parted powermgmt-base psmisc rsync sgml-base strace \
tcpdump telnet time uuid-runtime xml-core iptables resolvconf lsb-release openssh-server dbus

# Enable resolvconf.service
if [[ "$OS_VERSION" -ge "12" ]]
then
	systemctl start resolvconf-pull-resolved.service
	systemctl enable resolvconf-pull-resolved.service
else
	systemctl start resolvconf.service
	systemctl enable resolvconf.service
fi

# DHCP - START Set Google DNS nameservers
cat <<-EOF > /etc/resolvconf/resolv.conf.d/head
nameserver 8.8.8.8 
nameserver 8.8.4.4
EOF
# DHCP - END Set Google DNS nameservers

# Restart required services
if [[ "$OS_VERSION" -ge "12" ]]
then
	systemctl restart resolvconf-pull-resolved.service
	resolvconf -u
else
	systemctl restart resolvconf.service
	systemctl restart systemd-resolved.service
fi

# Install development tools
aptitude install -R -y linux-headers-amd64 build-essential

# Install drivers
aptitude install -R -y firmware-linux firmware-linux-free firmware-linux-nonfree

# Install additiona software
aptitude install -R -y safecat sharutils lynx zip unzip lrzip pbzip2 p7zip p7zip-full rar pigz unrar acpid \
zstd inotify-tools sysfsutils dstat htop lsscsi iotop nmap ifstat iftop tcptrack whois atop sysstat gpm \
localepurge mc screen vim ethtool apt-file sysdig net-tools sudo wget bsd-mailx dma pwgen

# In Debian -ge 12, netcat is virtual package
if [[ "$OS_VERSION" -ge "12" ]]
then
	aptitude install -R -y netcat-openbsd
else
	aptitude install -R -y netcat
fi
	
# Update apt-file
apt-file update
# Turn off screen startup message
sed -i 's/^#startup_message/startup_message/g' /etc/screenrc

# Configure Vim for root user
mkdir -p /root/.vim/saves
cat <<-EOF > /root/.vimrc
set tabstop=4
set softtabstop=4
set expandtab
set shiftwidth=4
set backupdir=~/.vim/saves/
set mousemodel=popup
EOF

# Backup distribution .bashrc
if [ -f "/root/.bashrc" ]
then
	cp /root/.bashrc /root/.bachrc.dist
fi
# Set custom bashrc env file
curl -Sso /root/.bashrc \
https://raw.githubusercontent.com/zjagust/debian-server-initial-customization/main/environment/.bashrc

# Generate root SSH keys
ssh-keygen -b 4096 -t rsa -f /root/.ssh/id_rsa -q -N ""

# Generate auth keys file for root
touch /root/.ssh/authorized_keys
chmod 0600 /root/.ssh/authorized_keys

# Add root's pub key to auth files
echo -e "from=\"127.0.0.1\" $(cat /root/.ssh/id_rsa.pub)" >> /root/.ssh/authorized_keys

# Add hypervisor's root SSH public key
echo -e "HYPER_SSH_ROOT_KEY\n" >> /root/.ssh/authorized_keys

# Add hypervisor's login user SSH key
#echo -e "HYPER_SSH_USER_KEY\n" >> /root/.ssh/authorized_keys

# Secure SSH access
sed -i 's/^#PermitRootLogin prohibit-password/PermitRootLogin without-password/g' /etc/ssh/sshd_config
sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config

# Restart SSH
systemctl restart ssh

# Add a comment
echo -e "\n# Debian NTP Pool Servers" >> /etc/hosts

# Set NTP variables
POOL_NTP_0=$(dig +short 0.pool.ntp.org | head -n1)
POOL_NTP_1=$(dig +short 1.pool.ntp.org | head -n1)
POOL_NTP_2=$(dig +short 2.pool.ntp.org | head -n1)
POOL_NTP_3=$(dig +short 3.pool.ntp.org | head -n1)
	
# Gather NTP IPs and add records to /etc/hosts
{

	echo -e "$POOL_NTP_0 0.debian.pool.ntp.org"
	echo -e "$POOL_NTP_1 1.debian.pool.ntp.org"
	echo -e "$POOL_NTP_2 2.debian.pool.ntp.org"
	echo -e "$POOL_NTP_3 3.debian.pool.ntp.org"
	
} >> /etc/hosts

# Install iptables-persistent and save rules
aptitude install -R -y iptables-persistent

# Fetch basic firewall
curl -Sso /etc/iptables/rules.v4 \
http://GATEWAY:8880/rules.v4
sed -i "s/POOL_NTP_0/$POOL_NTP_0/;s/POOL_NTP_1/$POOL_NTP_1/;s/POOL_NTP_2/$POOL_NTP_2/;s/POOL_NTP_3/$POOL_NTP_3/" /etc/iptables/rules.v4
chmod 0644 /etc/iptables/rules.v4

# Set asset log
curl -Sso /etc/update-motd.d/20-changes-log \
https://raw.githubusercontent.com/zjagust/debian-server-initial-customization/main/motd/20-changes-log
chmod 0755 /etc/update-motd.d/20-changes-log

# Create root work directory
mkdir /root/.work

# Clean APT cache
apt autoremove -y
aptitude clean
aptitude autoclean
# Reset debconf to full details
echo -e "debconf debconf/frontend select Dialog\ndebconf debconf/priority select low" | debconf-set-selections