#!/usr/bin/env bash

#######################################################################################################
#
# Zack's - KVM QEMU AutoInstall script
# Version: 1.0
#
# This script will automate the installation of KVM & QEMU
#
# © 2022 Zack's. All rights reserved.
#
#######################################################################################################

###########################
## SET COLOR & SEPARATOR ##
###########################
declare -gr SPACER='----------------------------------------------------------------------------------------------------'
declare -gr E=$'\e[0;31m'			# (E) Error: highlighted text.
declare -gr W=$'\e[1;33m'			# (W) Warning: highlighted text.
declare -gr I=$'\e[0;32m'			# (I) Info: highlighted text.
declare -gr B=$'\e[1m'				# B for Bold.
declare -gr R=$'\e[0m'				# R for Reset.

###############################
## CHECK ELEVATED PRIVILEGES ##
###############################
if [[ "$(whoami)" != "root" ]]
	then
		echo
		echo "${E}Script must be run with root privileges! Execution will abort now, please run script again as root user (or use sudo).${R}"
		echo
		exit 1
	fi

####################
## SCRIPT OPTIONS ##
####################
function setOptions () {

  # List Options
	cat <<-END
		${SPACER}
		${B}${I}KVM QEMU AUTO INSTALLER SCRIPT${R}
		${I}This script has multiple options. Documentation available at:${R}
		${B}https://github.com/zjagust/kvm-qemu-install-script ${R}
		${B}https://zacks.eu/kvm-qemu-installation-configuration ${R}
		${SPACER}
		The following options are available:
		 ${B}-h:${R} Print this help message
		 ${B}-r:${R} Check system readiness
		 ${B}-n:${R} Check how to enable Nesting (if -r shows it's disabled)
		 ${B}-z:${R} Check how to disable Zone Reclaim Mode (if -r shows it's enabled)
		 ${B}-s:${R} Check swappiness recommendations for your system
		 ${B}-d:${R} Check I/O scheduler recommendations for your disk devices
		 ${B}-i:${R} Install KVM QEMU. Recommended to run ${B}-r${R} first
		 ${B}-u:${R} Install helper scripts. KVM QEMU must be installed first (-i option above)!
		${SPACER}
	END
}

############################
## SET REQUIRED VARIABLES ##
############################
VIRT_CORES=$(grep -E -c '(vmx|svm)' /proc/cpuinfo)
CPU_ARCH=$(grep -E -c ' lm ' /proc/cpuinfo)
KERNEL_BUILD=$(uname -m)
CPU_VENDOR=$(grep 'vendor' /proc/cpuinfo | uniq | awk -F: '{print $2;}' | tr -d " ")
ZONE_RECLAIM=$(cat /proc/sys/vm/zone_reclaim_mode)
RAM_IN_GB=$(grep MemTotal /proc/meminfo | awk '{print $2 / (1024 * 1024)}' | LANG=C xargs /usr/bin/printf "%.*f\n" "$p")
SWAPPINESS=$(cat /proc/sys/vm/swappiness)
CONFIG_KVM_MOD=$(grep "CONFIG_KVM=" /boot/config-"$(uname -r)" | rev | cut -d"=" -f1)
CONFIG_VIRTIO_MOD=$(grep -E "CONFIG_VIRTIO_BLK|CONFIG_VIRTIO_NET|CONFIG_VIRTIO_BALLOON|CONFIG_VIRTIO=" /boot/config-"$(uname -r)" | rev | cut -d"=" -f1 | sort | uniq | tr -d '\n')
IPV4_FORWARDING=$(cat /proc/sys/net/ipv4/ip_forward)

#######################
## NESTING VARIABLES ##
#######################
if [ -f "/sys/module/kvm_amd/parameters/nested" ]; then
	NESTING_AMD=$(cat /sys/module/kvm_amd/parameters/nested)
else
	NESTING_INTEL=$(cat /sys/module/kvm_intel/parameters/nested)
fi

###################
## SYSTEM CHECKS ##
###################
function kvmReadiness () {

	## Check if CPU supports HW virtualization
	echo "${SPACER}"
	echo "${I}## HARDWARE VIRTUALIZATION ##${R}"
	echo "${SPACER}"
	if [ "$VIRT_CORES" == 0 ];
		then
			echo "${B}Checking if hardware virtualization (VT-x/AMD-V) is enabled${R} .......... ${W}[WARNING]${R}"
			echo "${W}Hardware virtualization is not available, but KVM QEMU can still be installed. Expect degraded performance${R}"
			sleep 1
		else
			echo "${B}Checking if hardware virtualization (VT-x/AMD-V) is enabled${R} .......... ${I}[PASSED]${R}"
			sleep 1
	fi
	echo "${SPACER}"

	# Check CPU architecture
	echo "${I}## CPU ARCHITECTURE ##${R}"
	echo "${SPACER}"
	if [ "$CPU_ARCH" == 0 ];
		then
			echo "${B}Checking CPU architecture${R} .......... ${W}[WARNING]${R}"
			echo "${W}You have a 32bit CPU. You will not be able to assign more than 2GB of RAM for your guests.${R}"
			sleep 1
		else
			echo "${B}Checking CPU architecture${R} .......... ${I}[PASSED]${R}"
			sleep 1
	fi
	echo "${SPACER}"

	# Check kernel build
	echo "${I}## KERNEL BUILD ##${R}"
	echo "${SPACER}"
	if [ "$KERNEL_BUILD" == x86_64 ];
		then
			echo "${B}Checking Kernel build${R} .......... ${I}[PASSED]${R}"
			sleep 1
		else
			echo "${B}Checking Kernel build${R} .......... ${W}[WARNING]${R}"
			echo "${W}You have a 32bit Kernel. You will not be able to assign more than 2GB of RAM for your guests.${R}"
			sleep 1
	fi
	echo "${SPACER}"

	# Check Nesting
	echo "${I}## NESTING ##${R}"
	echo "${SPACER}"
	if [ "$CPU_VENDOR" == GenuineIntel ]; then
		if [ "$NESTING_INTEL" == N ];
			then
				echo "${B}Checking if nesting is enabled${R} .......... ${E}[FAILED]${R}"
				echo "${E}Nesting is disabled. You can check how to enable it by executing this script with -n parameter.${R}"
				sleep 1
			else
				echo "${B}Checking if nesting is enabled${R} .......... ${I}[PASSED]${R}"
				sleep 1
		fi
	else
		if [ "$NESTING_AMD" == 0 ];
			then
				echo "${B}Checking if nesting is enabled${R} .......... ${E}[FAILED]${R}"
				echo "${E}Nesting is disabled. You can check how to enable it by executing this script with -n parameter.${R}"
				sleep 1
			else
				echo "${B}Checking if nesting is enabled${R} .......... ${I}[PASSED]${R}"
				sleep 1
		fi
	fi
	echo "${SPACER}"

	# Check Zone Reclaim Mode (essence of all evil)
	echo "${I}## ZONE RECLAIM MODE ##${R}"
	echo "${SPACER}"
	if [ -f "/proc/sys/vm/zone_reclaim_mode" ]; then
		if [ "$ZONE_RECLAIM" != 0 ];
			then
				echo "${B}Checking if Zone Reclaim Mode is off${R} .......... ${E}[FAILED]${R}"
				echo "${E}Zone Reclaim Mode is on. You can check how to disable it by executing this script with -z parameter.${R}"
				sleep 1
			else
				echo "${B}Checking if Zone Reclaim Mode is off${R} .......... ${I}[PASSED]${R}"
				sleep 1
		fi
	else
		echo "${B}Zone reclaim mode control file is missing${R} .......... ${B}[TEST SKIPPED]${R}"
	fi
	echo "${SPACER}"

	# Check KVM kernel module
	echo "${I}## KVM KERNEL MODULE ##${R}"
	echo "${SPACER}"
	if [ "$CONFIG_KVM_MOD" == m ] || [ "$CONFIG_KVM_MOD" == y ];
		then
			echo "${B}Checking if KVM kernel module is present${R} .......... ${I}[PASSED]${R}"
			sleep 1
		else
			echo "${B}Checking if KVM kernel module is present${R} .......... ${E}[FAILED]${R}"
			echo "${E}KVM kernel module is not present. You can either recompile the kernel${R}"
			echo "${E}or use a distribution with kernel that has per-built KVM module.${R}"
			sleep 1
	fi
	echo "${SPACER}"

	# Check basic VirtIO kernel module(s)
	echo "${I}## VIRTIO KERNEL MODULES ##${R}"
	echo "${SPACER}"
	if [ "$CONFIG_VIRTIO_MOD" == my ] || [ "$CONFIG_VIRTIO_MOD" == ym ] || [ "$CONFIG_VIRTIO_MOD" == m ] || [ "$CONFIG_VIRTIO_MOD" == y ];
		then
			echo "${B}Checking if basic VirtIO kernel module(s) is present${R} .......... ${I}[PASSED]${R}"
			sleep 1
		else
			echo "${B}Checking if basic VirtIO kernel module(s) is present${R} .......... ${E}[FAILED]${R}"
			echo "${E}VirtIO kernel module(s) is not present. You can either recompile the kernel${R}"
			echo "${E}or use a distribution with kernel that has per-built VirtIO modules.${R}"
			sleep 1
	fi
	echo "${SPACER}"

	# Check if swappiness is on default
	echo "${I}## SWAPPINESS ##${R}"
	echo "${SPACER}"
	if [ "$SWAPPINESS" -ge 60 ];
		then
			echo "${B}Checking swappiness value${R} .......... ${W}[WARNING]${R}"
			echo "${W}Swappiness is set on 60 (or more), a default for Debian based distributions. Please run the script${R}"
			echo "${W}with -s parameter to check swappiness recommendations for your system.${R}"
			sleep 1
		else
			echo "${B}Checking swappiness value${R} .......... ${I}[PASSED]${R}"
			echo "${I}Swappiness is set on less than 60 or disabled completely. It is recommended to run this script${R}"
			echo "${I}with -s parameter to check the recommended values for your system.${R}"
			sleep 1
	fi
	echo "${SPACER}"

	# Check if IPv4 forwarding is enabled
	echo "${I}## IPv4 FORWARDING ##${R}"
	echo "${SPACER}"
	if [ "$IPV4_FORWARDING" == 1 ];
		then
			echo "${B}Checking if IPv4 forwarding is enabled${R} .......... ${I}[PASSED]${R}"
			sleep 1
		else
			echo "${B}Checking if IPv4 forwarding is enabled${R} .......... ${E}[FAILED]${R}"
			echo "${E}IPv4 forwarding is disabled. You can enable it by executing the following command:${R}"
			echo "${E}\"sudo sed -i \"s\\#net.ipv4.ip_forward=1\\net.ipv4.ip_forward=1\\g\" /etc/sysctl.conf; sudo sysctl -p\"${R}"
			sleep 1
	fi
	echo "${SPACER}"

	# Check I/O scheduler
	echo "${I}## IO SCHEDULER ##${R}"
	echo "${SPACER}"
	lsblk -nd --output NAME | grep -E "sd|nvme" | while read -r line; do
		echo "Device $line has I/O scheduler set on $(grep -oP '\[.*?\]' /sys/block/"$line"/queue/scheduler | tr -d "[]")"
	done
	echo "If I/O scheduler for your ${B}HDD (rotational)${R} devices is not set on ${B}deadline${R} or ${B}mq-deadline${R}, and ${B}none${R} for your"
	echo "${B}SSD/NVMe${R} devices, then please execute this script with -d parameter to check the recommendations."
	echo "${SPACER}"

}

##############################
## VARIOUS CHECKS FUNCTIONS ##
##############################
function kvmNesting () {

	# Display enable nesting help
	echo "${SPACER}"
	echo "${I}## NESTING RECOMMENDATIONS ##${R}"
	echo "${SPACER}"
	if [ "$CPU_VENDOR" == GenuineIntel ]; then
		if [ "$NESTING_INTEL" == N ];
			then
				echo "${B}Nesting on your system is disabled. To enable it, please open /etc/default/grub file in text editor,${R}"
				echo "${B}and set kvm-intel.nested=1 parameter in GRUB_CMDLINE_LINUX (i.e., GRUB_CMDLINE_LINUX=\"kvm-intel.nested=1\")${R}"
				sleep 1
			else
				echo "${B}Nesting is already enabled on your system.${R}"
				sleep 1
		fi
	else
		if [ "$NESTING_AMD" == 0 ];
			then
				echo "${B}Nesting on your system is disabled. To enable it, please open /etc/default/grub file in text editor,${R}"
				echo "${B}and set kvm-amd.nested=1 parameter in GRUB_CMDLINE_LINUX (i.e., GRUB_CMDLINE_LINUX=\"kvm-amd.nested=1\")${R}"
				sleep 1
			else
				echo "${B}Nesting is already enabled on your system.${R}"
				sleep 1
		fi
	fi
	echo "${SPACER}"

}

function kvmZRM () {

	# Display Zone Reclaim Mode help
	echo "${SPACER}"
	echo "${I}## ZONE RECLAIM MODE RECOMMENDATIONS ##${R}"
	echo "${SPACER}"
	if [ -f "/proc/sys/vm/zone_reclaim_mode" ]; then
		if [ "$ZONE_RECLAIM" != 0 ];
			then
				echo "${B}Zone Reclaim Mode is enabled on your system. To disable it, please execute the following commands:${R}"
				echo "${B}\"echo 0 > /proc/sys/vm/zone_reclaim_mode\" and \"sed -i "\\\$a# Disable zone reclaim\\nvm.zone_reclaim_mode=0" /etc/sysctl.conf\"${R}"
				sleep 1
			else
				echo "${B}Zone Reclaim Mode is already disabled on your system.${R}"
				sleep 1
		fi
	else
		echo "${B}Zone reclaim mode control file is not present on this computer. Will exit now.${R}"
	fi
	echo "${SPACER}"

}

function kvmEnvironment () {

	IS_DESKTOP="false"
	
	displayManager=(
		'xserver-common' # X Window System (X.Org) infrastructure
		'xwayland' # Xwayland X server
	)

	for i in "${displayManager[@]}"; do
		dpkg-query --show --showformat='${Status}\n' "$i" 2> /dev/null | grep "install ok installed" &> /dev/null
		if [[ $? -eq 0 ]];
			then
				IS_DESKTOP="true"
		fi
	done

}

function kvmSwappiness () {

	# Display swappiness recommendations
	echo "${SPACER}"
	echo "${I}## SWAPPINESS RECOMMENDATIONS ##${R}"
	echo "${SPACER}"
	if [ "$IS_DESKTOP" == true ] && [ "$RAM_IN_GB" -le 16 ];
		then
			echo "${B}You're running a Desktop system with 16GB or less RAM. You can leave swappiness on default.${R}"
	elif [ "$IS_DESKTOP" == true ] && [ "$RAM_IN_GB" -gt 16 ];
		then 
			echo "${B}You're running a Desktop system with more than 16 GB RAM. You can set swappiness on 35 by${R}"
			echo "${B}executing the following commands: \"echo 35 > /proc/sys/vm/swappiness\" and \"sed -i '\$a# Set swappiness\\nvm.swappiness=35' /etc/sysctl.conf\"${R}"
	elif [ "$IS_DESKTOP" == false ] && [ "$RAM_IN_GB" -le 16 ];
		then
			echo "${B}You're running a Server system with 16BG or less RAM. You can set swappiness on 35 by${R}"
			echo "${B}executing the following commands: \"echo 35 > /proc/sys/vm/swappiness\" and \"sed -i '\$a# Set swappiness\\nvm.swappiness=35' /etc/sysctl.conf\"${R}"
	else
		echo "${B}You're running a Server system with at least 16 GB RAM. If you're running services other than KVM and QEMU,${R}"
		echo "${B}you can set swappiness on 30. If this is a dedicated KVM QEMU server, you can set swappiness on 1${R}"
		echo "${B}(i.e., \"echo 1 > /proc/sys/vm/swappiness\" and \"sed -i '\$a# Set swappiness\\nvm.swappiness=1' /etc/sysctl.conf\").${R}"
	fi
	echo "${SPACER}"

}

function kvmIOScheduler () {

	# Display I/O scheduler recommendations
	echo "${SPACER}"
	echo "${I}## I/O Scheduler RECOMMENDATIONS ##${R}"
	echo "${SPACER}"
	lsblk -nd --output NAME | grep -E "sd|nvme" | while read -r line; do
		if [ "$(cat /sys/block/"$line"/queue/rotational)" == 0 ]; then
			echo "Device $line is SSD or NVMe device and has I/O scheduler set on $(grep -oP '\[.*?\]' /sys/block/"$line"/queue/scheduler | tr -d "[]")."
			echo "If I/O scheduler is not set on ${B}none${R}, you can set it by executing  \"echo none > /sys/block/$line/queue/scheduler\""
		else
			echo "Device $line is HDD (rotational) device and has I/O scheduler set on $(grep -oP '\[.*?\]' /sys/block/"$line"/queue/scheduler | tr -d "[]")."
			echo "If I/O scheduler is not set on ${B}deadline${R} or ${B}mq-deadline${R}, you can set it by executing  \"echo deadline > /sys/block/$line/queue/scheduler\""
		fi
	done
	echo "${SPACER}"

}

#####################
## GUEST BEHAVIOUR ##
#####################

function kvmGuestConfig () {

	# Display Info
	cat <<-END

		${SPACER}

		  ${B}** GUEST BEHAVIOUR ON HOST SHUTDOWN **${R}

		  The default behaviour of libvirtd is to shutdown all guests (VMs) once the host is shut down.
		  This can be changed to instruct libvirtd to suspend all guests using virsh managedsave.

		${SPACER}

	END

	# Ask for conformation
	local ANSWER
	read -rp "Type ${B}Y${R} to change the behaviour for guest machines from shutdown to suspend, or just press Enter to leave the default: ${B}" ANSWER
	echo "${R}"

	# Change behaviour
	if [[ "${ANSWER, }" != 'y' ]]; then
		echo
		echo "Nothing changed, will continue now."
		echo
	else
		echo
		echo "Changing default from shutdown to suspend."
		echo
		sed -i -e 's/#ON_SHUTDOWN=shutdown/ON_SHUTDOWN=suspend/g' /etc/default/libvirt-guests
	fi

}

#############################
## ENABLE LISTENING SOCKET ##
#############################

function kvmTCPSocket () {

	# Display Info
	cat <<-END

		${SPACER}

		  ${B}** LibVirtd TCP Socket **${R}

		  Libvirtd can be started with listening TCP socket. This is usually useful when building a 
		  "cluster" of libvirt machines and you want to enable a live guest migration between hosts
		  in that cluster. When enabled, port 16509 will be opened and will listen on all interfaces.

		${SPACER}

	END

	# Ask for conformation
	local ANSWER
	read -rp "Type ${B}Y${R} to enable libvirtd TCP socket service, or press Enter to continue without it: ${B}" ANSWER
	echo "${R}"

	# Enable TCP socket
	if [[ "${ANSWER, }" != 'y' ]]; then
		echo
		echo "Nothing changed, will continue now."
		echo
	else
		echo
		echo "Enabling libvirtd TCP socket service."
		systemctl enable libvirtd-tcp.socket
	fi

}

###################
## INSTALL POOLS ##
###################

function poolInstall () {

	# Notify
	echo "${SPACER}"
	echo "${B} ** Setting dir based pools ** ${R}"
	echo "${SPACER}"

	# Remove default pools
	EXISTING_POOL=$(virsh pool-list --all | tail -n +3 | awk '{print $1}')
	POOL_STATE=$(virsh pool-list --all | tail -n +3 | awk '{print $2}')
	if [[ -n "$EXISTING_POOL" && "$POOL_STATE" == "active" ]]; then
		virsh pool-destroy "$EXISTING_POOL"
		virsh pool-undefine "$EXISTING_POOL"
	elif [[ -n "$EXISTING_POOL" && "$POOL_STATE" == "inactive" ]]; then
		virsh net-undefine "$EXISTING_POOL"
	else
		echo "${I}No default pools found, continuing${R}"
	fi

	# Set default pool
	virsh pool-define-as default dir - - - - "/home/libvirt/vm_images"
	virsh pool-build default
	virsh pool-start default
	virsh pool-autostart default

	# Set ISO pool
	virsh pool-define-as iso dir - - - - "/home/libvirt/iso_images"
	virsh pool-build iso
	virsh pool-start iso
	virsh pool-autostart iso

}

######################
## INSTALL NETWORKS ##
######################

function netInstall () {

	# Notify
	echo "${SPACER}"
	echo "${B} ** Setting virtual networks ** ${R}"
	echo "${SPACER}"

	# Remove default network
	EXISTING_NET=$(virsh net-list --all | tail -n +3 | awk '{print $1}')
	NET_STATE=$(virsh net-list --all | tail -n +3 | awk '{print $2}')
	if [[ -n "$EXISTING_NET" && "$NET_STATE" == "active" ]]; then
		virsh net-destroy "$EXISTING_NET"
		virsh net-undefine "$EXISTING_NET"
	elif [[ -n "$EXISTING_NET" && "$NET_STATE" == "inactive" ]]; then
		virsh net-undefine "$EXISTING_NET"
	else
		echo "${I}No default networks found, continuing${R}"
	fi

	# Set default NAT network with DHCP
	curl -Sso /tmp/default-nat-dhcp.xml https://raw.githubusercontent.com/zjagust/kvm-qemu-install-script/main/networks/default-nat-dhcp.xml
	virsh net-define /tmp/default-nat-dhcp.xml
	virsh net-autostart default-nat-dhcp
	virsh net-start default-nat-dhcp

	# Set default NAT static network
	curl -Sso /tmp/default-nat-static.xml https://raw.githubusercontent.com/zjagust/kvm-qemu-install-script/main/networks/default-nat-static.xml
	virsh net-define /tmp/default-nat-static.xml
	virsh net-autostart default-nat-static
	virsh net-start default-nat-static

	# Set default isolated network
	curl -Sso /tmp/default-isolated.xml https://raw.githubusercontent.com/zjagust/kvm-qemu-install-script/main/networks/default-isolated.xml
	virsh net-define /tmp/default-isolated.xml
	virsh net-autostart default-isolated
	virsh net-start default-isolated

}

######################
## INSTALL KVM QEMU ##
######################
function kvmInstall () {
	# Clear screen
	clear

	# Show a warning.
	cat <<-END

		${SPACER}

		  ${B}** IMPORTANT **${R}

		  You are about to install several packages required for KVM and QEMU. Please make sure you execute
		  this script with ${B}-r${R} parameter prior installation to perform required checks and recommendations.
		  For a complete guide on KVM and QEMU, please refer to https://zacks.eu/kvm-qemu-installation-configuration.

		${SPACER}

	END

	# Ask for confirmation.
	local ANSWER
	read -rp "Type ${B}Y${R} to proceed, or anything else to cancel, and press Enter: ${B}" ANSWER
	echo "${R}"

	# Terminate if required.
	if [[ "${ANSWER,}" != 'y' ]]; then
		echo
		echo 'Terminated. Nothing done.'
		echo
		exit 1
	fi

	# Environment check
	kvmEnvironment

	# Install required packages
	DEBIAN_FRONTEND=noninteractive aptitude install -y bridge-utils \
	libvirt-clients \
	libvirt-daemon-system \
	libvirt-daemon \
	qemu-system-x86 \
	qemu-utils \
	dnsmasq-base \
	virtinst \
	ovmf \
	xsltproc \
	grepcidr

	# Check if desktop
	if [ "$IS_DESKTOP" == true ];
		then
			local VIRT_MANAGER
			read -rp "You are running a Desktop system. Would you like to install Virtual Manager GUI (y/n): ${B}" VIRT_MANAGER
			echo "${R}"
			if [[ "${VIRT_MANAGER,}" == 'y' ]]; then
				apt install -y virt-manager
			else
				echo
				echo "Virtual Manager GUI will not be installed."
				echo
			fi
	fi

	# Add install user to correct groups
	if [ -z "$SUDO_USER" ]; then
		echo "User is root, no group additions."
	else
		usermod -a -G libvirt,kvm "$SUDO_USER"
	fi

	# Action taken on host shutdown
	kvmGuestConfig

	# Libvirtd TCP socket
	kvmTCPSocket

	## ADDITIONAL COMPONENTS - Install and configure webfs
	# Set host gateway
	HOST_GATEWAY=$(ip route get "$(ip route show 0.0.0.0/0 | grep -oP 'via \K\S+')" | grep -oP 'src \K\S+')
	# Install required packages
	DEBIAN_FRONTEND=noninteractive aptitude install -R -y webfs
	# Stop WebFS service
	WEBFSD_PID=$(pidof webfsd)
	systemctl stop webfs
	# Required due to bug -> https://www.mail-archive.com/debian-bugs-dist@lists.debian.org/msg1674524.html
	kill -9 "$WEBFSD_PID"
	# Create WebFS directories and set proper ownership
	mkdir -p /home/webfs/{htdocs,logs}
	touch /home/webfs/logs/access.log
	chown -R nobody:nogroup /home/webfs/{htdocs,logs}
	chown -R nobody:nogroup /var/run/webfs
	# Set WebFS config
	if [[ -f "/etc/webfsd.conf" ]]
	then
		mv /etc/webfsd.conf /etc/webfsd.conf.dist
		curl -Sso /etc/webfsd.conf \
		https://raw.githubusercontent.com/zjagust/kvm-qemu-install-script/main/additional-components/webfsd.conf
	else
		curl -Sso /etc/webfsd.conf \
		https://raw.githubusercontent.com/zjagust/kvm-qemu-install-script/main/additional-components/webfsd.conf
	fi
	# Enable and start WebFS service
	systemctl enable webfs
	systemctl start webfs
	# Set firewall
	iptables -N KVM-SERVICES
	iptables -I INPUT -m comment --comment "KVM Services" -j KVM-SERVICES
	iptables -A KVM-SERVICES -p tcp -m tcp -s 172.16.0.0/24 -d "$HOST_GATEWAY" --dport 8880 -m comment --comment "WebFS Access - KVM Default NAT DHCP Network" -j ACCEPT
	iptables -A KVM-SERVICES -p tcp -m tcp -s 172.17.0.0/24 -d "$HOST_GATEWAY" --dport 8880 -m comment --comment "WebFS Access - KVM Default NAT Static Network" -j ACCEPT

}

function installComplete () {
	
	# Display install info message
	echo "${SPACER}"
	echo "${I}## INSTALLATION COMPLETE ##${R}"
	echo "${SPACER}"
	echo "For any additional information, please visit:"
	echo "${B}https://github.com/zjagust/kvm-qemu-install-script ${R}"
	echo "${B}https://zacks.eu/kvm-qemu-installation-configuration ${R}"
	echo "${SPACER}"

}

####################################
## PRE-INSTALL UTILS SYSTEM CHECK ##
####################################

function systemChecks () {

	# System Checks Header
	echo
	echo "${SPACER}"
	echo "${B}** MANDATORY SYSTEM CHECKS **${R}"
	echo "${SPACER}"
	
	# Check if libvirtd is running
	if [[ -f "/var/run/libvirtd.pid" ]]
	then
		echo "${I}Libvirtd is installed and running.${R}"
		sleep 1
	else
		echo "${E}Libvirtd is either not running or it is not installed on this machine. Will exit now.${R}"
		exit 1
	fi

	# Check if virsh is installed
	if [[ -f "/usr/bin/virsh" ]]
	then
		echo "${I}Virsh is installed.${R}"
		sleep 1
	else
		echo "${E}Cannot find virsh. Looks like libvirt-clients package is not installed. Will exit now.${R}"
		exit 1
	fi

	# Check if qemu-img is installed
	if [[ -f "/usr/bin/qemu-img" ]]
	then
		echo "${I}Qemu-img is installed.${R}"
		sleep 1
	else
		echo "${E}Cannot find qemu-img. Looks like qemu-utils package is not installed. Will exit now.${R}"
		exit 1
	fi

	# Check if xsltproc is installed
	if [[ -f "/usr/bin/xsltproc" ]]
	then
		echo "${I}Xsltproc is installed.${R}"
		sleep 1
	else
		echo "${E}Cannot find xsltproc. Looks like xsltproc package is not installed. Will exit now.${R}"
		exit 1
	fi

	# Check if curl is installed
	if [[ -f "/usr/bin/curl" ]]
	then
		echo "${I}Curl is installed.${R}"
		sleep 1
	else
		echo "${E}Cannot find curl. Looks like curl package is not installed. Will exit now.${R}"
		exit 1
	fi

	# Check if ca-certificates is installed
	CA_CERTS_CHECK=$(dpkg -l | grep -E "(^| )ca-certificates( |$)" | awk '{print $1}')
	if [[ "$CA_CERTS_CHECK" == "ii" ]]
	then
		echo "${I}Ca-certificates are installed.${R}"
		sleep 1
	else
		echo "${E}Cannot confirm ca-certificates installation. Looks like ca-certificates package is not installed. Will exit now.${R}"
		exit 1
	fi

	# System Checks Footer
	echo "${SPACER}"

}

###################
## INSTALL UTILS ##
###################
function utilsInstall () {

	# Display Info
	cat <<-END

		${SPACER}

		  ${B}** KVM QEMU Helper Scripts **${R}

		  This will install a collection of "helper" scripts compatible with the installation of 
		  Libvirt/KVM/QEMU performed by this script. New scripts to this bundle may be added 
		  periodically, as well as updates to the existing ones. For more info, please visit:
		  https://github.com/zjagust/kvm-qemu-install-script/resources/README.md		  

		${SPACER}

	END

	# Ask for confirmation.
	local ANSWER
	read -rp "Type ${B}Y${R} to proceed, or anything else to cancel, and press Enter: ${B}" ANSWER
	echo "${R}"

	# Terminate if required.
	if [[ "${ANSWER,}" != 'y' ]]; then
		echo
		echo 'Terminated. Nothing done.'
		echo
		exit 1
	fi

	# Prerequisites
	systemChecks

	# Install kvm-guest-actions script
	curl -Sso /usr/local/sbin/kvm-guest-actions https://raw.githubusercontent.com/zjagust/kvm-qemu-install-script/main/resources/kvm-guest-actions.sh
	if [[ "$?" == 0 ]]; then
		chown root:root /usr/local/sbin/kvm-guest-actions
		chmod 0755 /usr/local/sbin/kvm-guest-actions
		echo "${I}Script kvm-guest-actions successfully installed at /usr/local/sbin/kvm-guest-actions.${R}"
		echo "${I}Run ${B}sudo kvm-guest-actions${R} without any parameters to display available options${R}"
	else
		echo "${E}Script installation failed, something went wrong. Will exit now.${R}"
		exit 1
	fi

	# Install guest config xml file parser for storage
	curl -Sso /etc/libvirt/qemu/guest_storage_list.xsl https://raw.githubusercontent.com/zjagust/kvm-qemu-install-script/main/resources/guest_storage_list.xsl
	if [[ "$?" == 0 ]]; then
		chown root:root /etc/libvirt/qemu/guest_storage_list.xsl
		chmod 0644 /etc/libvirt/qemu/guest_storage_list.xsl
		echo "${I}XML parser guest_storage_list.xsl successfully installed at /etc/libvirt/qemu/guest_storage_list.xsl.${R}"
	else
		echo "${E}XML storage parser file installation failed, something went wrong. Will exit now.${R}"
		exit 1
	fi

	# Install guest config xml file parser for network
	curl -Sso /etc/libvirt/qemu/networks/guest_network_list.xsl https://raw.githubusercontent.com/zjagust/kvm-qemu-install-script/main/resources/guest_network_list.xsl
	if [[ "$?" == 0 ]]; then
		chown root:root /etc/libvirt/qemu/networks/guest_network_list.xsl
		chmod 0644 /etc/libvirt/qemu/networks/guest_network_list.xsl
		echo "${I}XML parser guest_network_list.xsl successfully installed at /etc/libvirt/qemu/networks/guest_network_list.xsl.${R}"
	else
		echo "${E}XML network parser file installation failed, something went wrong. Will exit now.${R}"
		exit 1
	fi

	# Install kvm-debian-server-unattended script
	curl -Sso /usr/local/sbin/kvm-debian-server-unattended https://raw.githubusercontent.com/zjagust/kvm-qemu-install-script/main/resources/kvm-debian-server-unattended.sh
	if [[ "$?" == 0 ]]; then
		chown root:root /usr/local/sbin/kvm-debian-server-unattended
		chmod 0755 /usr/local/sbin/kvm-debian-server-unattended
		echo "${I}Script kvm-debian-server-unattended successfully installed at /usr/local/sbin/kvm-debian-server-unattended.${R}"
		echo "${I}Run ${B}sudo kvm-debian-server-unattended${R} without any parameters to display available options${R}"
	else
		echo "${E}Script installation failed, something went wrong. Will exit now.${R}"
		exit 1
	fi

	# Set preseed files required for kvm-debian-server-unattended
	if [[ -d /etc/libvirt/qemu/preseed ]]; then
		curl -Sso /etc/libvirt/qemu/preseed/debian-server-dhcp-preseed.cfg https://raw.githubusercontent.com/zjagust/kvm-qemu-install-script/main/resources/preseed/debian-server-dhcp-preseed.cfg
		curl -Sso /etc/libvirt/qemu/preseed/debian-server-static-preseed.cfg https://raw.githubusercontent.com/zjagust/kvm-qemu-install-script/main/resources/preseed/debian-server-static-preseed.cfg
		if [[ "$?" == 0 ]]; then
			chown root:root /etc/libvirt/qemu/preseed/debian-server-*
			chmod 0755 /etc/libvirt/qemu/preseed/debian-server-*
			echo "${I}Debian Server preseed configurations successfully installed at /etc/libvirt/qemu/preseed/debian-server-*-preseed.cfg.${R}"
		else
			echo "${E}Script installation failed, something went wrong. Will exit now.${R}"
			exit 1
		fi
	else
		mkdir -p /etc/libvirt/qemu/preseed/
		curl -Sso /etc/libvirt/qemu/preseed/debian-server-dhcp-preseed.cfg https://raw.githubusercontent.com/zjagust/kvm-qemu-install-script/main/resources/preseed/debian-server-dhcp-preseed.cfg
		curl -Sso /etc/libvirt/qemu/preseed/debian-server-static-preseed.cfg https://raw.githubusercontent.com/zjagust/kvm-qemu-install-script/main/resources/preseed/debian-server-static-preseed.cfg
		if [[ "$?" == 0 ]]; then
			chown root:root /etc/libvirt/qemu/preseed/debian-server-*
			chmod 0755 /etc/libvirt/qemu/preseed/debian-server-*
			echo "${I}Debian Server preseed configurations successfully installed at /etc/libvirt/qemu/preseed/debian-server-*-preseed.cfg.${R}"
		else
			echo "${E}Script installation failed, something went wrong. Will exit now.${R}"
			exit 1
		fi
	fi

	# Set Debian Server preseed late-install resources
	if [[ -d /etc/libvirt/qemu/late-install ]]; then
		curl -Sso /etc/libvirt/qemu/late-install/debian-server-late-install.sh https://raw.githubusercontent.com/zjagust/kvm-qemu-install-script/main/resources/late-install/debian-server-late-install.sh
		curl -Sso /etc/libvirt/qemu/late-install/basic-firewall https://raw.githubusercontent.com/zjagust/kvm-qemu-install-script/main/resources/late-install/basic-firewall
		if [[ "$?" == 0 ]]; then
			chown root:root /etc/libvirt/qemu/late-install/*
			chmod 0755 /etc/libvirt/qemu/late-install/*
			echo "${I}Debian Server preseed late-install resources successfully installed at /etc/libvirt/qemu/late-install/.${R}"
		else
			echo "${E}Script installation failed, something went wrong. Will exit now.${R}"
			exit 1
		fi
	else
		mkdir -p /etc/libvirt/qemu/late-install/
		curl -Sso /etc/libvirt/qemu/late-install/debian-server-late-install.sh https://raw.githubusercontent.com/zjagust/kvm-qemu-install-script/main/resources/late-install/debian-server-late-install.sh
		curl -Sso /etc/libvirt/qemu/late-install/basic-firewall https://raw.githubusercontent.com/zjagust/kvm-qemu-install-script/main/resources/late-install/basic-firewall
		if [[ "$?" == 0 ]]; then
			chown root:root /etc/libvirt/qemu/late-install/*
			chmod 0755 /etc/libvirt/qemu/late-install/*
			echo "${I}Debian Server preseed late-install resources successfully installed at /etc/libvirt/qemu/late-install/.${R}"
		else
			echo "${E}Script installation failed, something went wrong. Will exit now.${R}"
			exit 1
		fi
	fi

}

#################
## GET OPTIONS ##
#################

# No parameters
if [ $# -eq 0 ]; then
	setOptions
	exit 1
fi

# Execute
while getopts ":hrnzsdiu" option; do
	case $option in
		h) # Display help message
			setOptions
			exit
			;;
		r) # Check system readiness
			kvmReadiness
			exit
			;;
		n) # Show how to enable Nesting
			kvmNesting
			exit
			;;
		z) # Show how to disable Zone Reclaim Mode
			kvmZRM
			exit
			;;
		s) # Show swappiness recommendations
			kvmEnvironment
			kvmSwappiness
			exit
			;;
		d) # Show I/O scheduler recommendations
			kvmIOScheduler
			exit
			;;
		i) # Install KVM QEMU
			kvmInstall
			poolInstall
			netInstall
			installComplete
			exit
			;;
		u) # Install KVM QEMU utils
			utilsInstall
			exit
			;;
		\?) # Invalid options
			echo "Invalid option, will exit now."
			exit
			;;
	esac
done
