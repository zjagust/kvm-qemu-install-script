#!/usr/bin/env bash

#######################################################################################################
#
# Zack's - Debian Unattended installation for KVM
# Version: 1.0
#
# This script will will perform automated, unattended installation of Debian Server operating system
# on a KVM/Libvirt guest (virtual machine).
#
# Supported Debian versions >= 11 (codename Bullseye)
#
# © 2023 Zack's. All rights reserved.
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
		${B}${I}KVM DEBIAN UNATTENDED INSTALL${R}
		${SPACER}
		${I}This script will perform unattended installation of Debian operating system${R}
		${I}on a KVM/QEMU (libvirt) enabled hypervisor. Script requires several arguments${R}
		${I}to be provided with -i option, which are listed below:${R}
		  ${B}1) Guest Name${R} (example: debian-vm)
		  ${B}2) Disk Size${R} (in MiB, example (for 10GB): 10240)
		  ${B}3) RAM Size${R} (in MiB, example (for 4GB): 4096)
		  ${B}4) VCPU Count${R} (example (for 4 cores): 4)
		  ${B}5) Debian Distro Name${R} (example: bookworm)
		  ${B}6) Virtual Network${R} (example: default)
		  ${B}7) Root Plain Password${R} (example: passpass)
		  ${B}8) Boot Mode${R} (Use either ${B}legacy${R} or ${B}uefi${R})
		  ${B}9) Static IP${R} (This parameter is optional. Use only if non-DHCP virtual network is selected in (6))
		  ${B}!! IT IS MANDATORY TO USE ARGUMENTS IN THE ORDER DISPLAYED ABOVE !!${R}
		${SPACER}
		${B}DHCP Network, legacy boot mode VM example:${R}
		  "$0" -i debian-bookwork 10240 2048 1 bookworm default-nat-dhcp passpass legacy
		${B}Static Network, uefi boot mode VM example:${R}
		  "$0" -i debian-bookwork 10240 2048 1 bookworm default-nat-static passpass uefi 172.17.0.2
		${SPACER}
		The following options are available:
		 ${B}-h:${R} Print this help message
		 ${B}-l:${R} List all virtual machines
		 ${B}-s:${R} List supported Debian distributions
		 ${B}-n:${R} List available networks info
		 ${B}-i:${R} Install Debian guest machine
		${SPACER}
	END
}

###################
## SYSTEM CHECKS ##
###################

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

	# Check if WebFS in installed and running
	if [[ -f "/var/run/webfs/webfsd.pid" ]]
	then
		echo "${I}WebFS service is installed and running.${R}"
		sleep 1
	else
		echo "${E}WebFS is either not running or it is not installed on this machine. Will exit now.${R}"
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

	# Check if virt-install is installed
	if [[ -f "/usr/bin/virt-install" ]]
	then
		echo "${I}Virt-install is installed.${R}"
		sleep 1
	else
		echo "${E}Cannot find virt-install. Looks like virtinst package is not installed. Will exit now.${R}"
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

	# Check if grepcidr is installed
	if [[ -f "/usr/bin/virt-xml" ]]
	then
		echo "${I}Virt-xml is installed.${R}"
		sleep 1
	else
		echo "${E}Cannot find virt-xml. Looks like virtinst package is not installed. Will exit now.${R}"
		exit 1
	fi

	# Check if virt-xml is installed
	if [[ -f "/usr/bin/grepcidr" ]]
	then
		echo "${I}Grepcidr is installed.${R}"
		sleep 1
	else
		echo "${E}Cannot find grepcidr. Looks like grepcidr package is not installed. Will exit now.${R}"
		exit 1
	fi

	# Check if /home/libvirt/VM_IMAGES exists
	if [[ -d "/home/libvirt/vm_images" ]]
	then
		echo "${I}Directory /home/libvirt/vm_images exists.${R}"
		sleep 1
	else
		echo "${E}Directory /home/libvirt/vm_images is not present.${E}"
		echo "${I}Please check https://github.com/zjagust/kvm-qemu-install-script/ to help resolve the error.${R}"
		exit 1
	fi

	# Check if guest_network_list.xsl exists
	if [[ -f "/etc/libvirt/qemu/networks/guest_network_list.xsl" ]]
	then
		echo "${I}File guest_network_list.xsl is present.${R}"
		sleep 1
	else
		echo "${E}Cannot find guest_network_list.xsl.${R}"
		echo "${I}Please check https://github.com/zjagust/kvm-qemu-install-script/ to help resolve the error.${R}"
		exit 1
	fi

	# Check if installed-guests.csv exists
	if [[ -f "/etc/libvirt/qemu/installed-guests.csv" ]]
	then
		echo "${I}File installed-guests.csv is present.${R}"
		sleep 1
	else
		echo "${W}Cannot find installed-guests.csv.${R}"
		echo "${I}Assuming this is the first guest on this hypervisor.${R}"
		echo "${I}Will create /etc/libvirt/qemu/installed-guests.csv file.${R}"
		touch /etc/libvirt/qemu/installed-guests.csv
		echo "GUEST_NAME,ROOT_PASS,IP_ADDRESS,VIRTUAL_NETWORK" >> /etc/libvirt/qemu/installed-guests.csv
		exit 1
	fi

}

###################################
## LIST EXISTING GUESTS & CHECKS ##
###################################

function existingGuestCheck () {

	# Set required variables
	INSTALLED_GUESTS="/etc/libvirt/qemu/installed-guests.csv"
	EXISTING_GUEST=$(< "$INSTALLED_GUESTS" sed 's/,/ ,/g' | column -t -s, | grep "$2" | awk '{print $1}')

	# Existing guest check
	if [[ "$2" == "$EXISTING_GUEST" ]]
	then
		echo "${E}Guest $2 already exist. Please choose a different name for your guest.${R}"
		echo "${SPACER}"
		exit 1
	fi

}

function listExistingGuests () {

	# Set required variables
	INSTALLED_GUESTS="/etc/libvirt/qemu/installed-guests.csv"

	# List already existsing guest VMs
	echo
	echo "${SPACER}"
	echo "${B}** EXISTING GUEST LIST **${R}"
	echo "${SPACER}"
	echo
	< "$INSTALLED_GUESTS" sed 's/,/ ,/g' | column -t -s,
	echo "${SPACER}"

}

################################
## SUPPORTED DISTROS & CHECKS ##
################################

function supportedDistorsCheck () {

	# Check distribution
	if [[ "$6" != "bullseye" && "$6" != "bookworm" ]]; then
		echo "${E}Wrong distribution selected.${R}"
		echo "${I}Execute \"$0 -s\" to list supported Debian distributions${R}"
		exit 1
	fi

}

function listSupportedDistros () {

	echo "${SPACER}"
	echo "${B}** SUPPORTED DEBIAN DISTRIBUTIONS **${R}"
	echo "${SPACER}"
	echo "${I}Supported Debian distributions are: ${R}"
	echo "${B}bullseye${R}"
	echo "${B}bookworm${R}"
	echo "${SPACER}"

}

#################################
## AVAILABLE NETWORKS & CHECKS ##
#################################

function availableNetworks () {

	# Set networks xsl parser
	NETWORKS_SHEET="/etc/libvirt/qemu/networks/guest_network_list.xsl"

	# List all available networks and their info
	echo "${SPACER}"
	echo "${B} ** LIST INFO ON ALL AVAILABLE NETWORKS ** ${R}"
	echo "${SPACER}"
	pushd /etc/libvirt/qemu/networks > /dev/null || exit
		for NETWORKS in *.xml; do
			basename "$NETWORKS" .xml
			xsltproc $NETWORKS_SHEET "$NETWORKS"
		done
	popd > /dev/null || exit

}

###############
## CREATE VM ##
###############

function installDebianServer () {

	# Check distribution and guest name
	existingGuestCheck "$@"
	supportedDistorsCheck "$@"

	# Set distribution
	if [[ "$6" == "bullseye" ]]; then
		SET_DISTRO="11"
	else
		SET_DISTRO="12"
	fi

	# Set host gateway
	HOST_GATEWAY=$(ip route get "$(ip route show 0.0.0.0/0 | grep -oP 'via \K\S+')" | grep -oP 'src \K\S+')

	# Set host SSH public key
	HOST_ROOT_KEY=$(cat /root/.ssh/id_rsa.pub)

	# Generate root password
	ROOT_PASS=$(mkpasswd -m sha-512 -S "$(pwgen -ns 16 1)" "$8")

	# Generate preseed configuration
	if [[ "$7" == "default-nat-dhcp" ]]; then
		cp /etc/libvirt/qemu/preseed/debian-server-dhcp-preseed.cfg /tmp/preseed.cfg
	elif [[ "$7" == "default-nat-static" ]]; then
		cp /etc/libvirt/qemu/preseed/debian-server-static-preseed.cfg /tmp/preseed.cfg
	else
		echo "${E}Unsupported network selected.${R}"
		echo "${I}Supported networks are default-nat-static and default-nat-dhcp.${R}"
		exit 1
	fi

	## Populate preseed configuration with correct arguments
	# Set hostname
	sed -i "s@d-i netcfg/get_hostname string HOSTNAME@d-i netcfg/get_hostname string $2@g" /tmp/preseed.cfg
	# Set root password
	sed -i "s@d-i passwd/root-password-crypted password PASSWORD@d-i passwd/root-password-crypted password $ROOT_PASS@g" /tmp/preseed.cfg
	# Set late-install WebFS listen IP
	sed -i "s/HYPER_GW/$HOST_GATEWAY/g" /tmp/preseed.cfg
	# Set network
	if [[ "$7" == "default-nat-static" ]]; then
		# Set required variables
		STATIC_RANGE="172.17.0.1/24"
		CORRECT_IP=$(grepcidr "$STATIC_RANGE" <(echo "${10}"))
		EXISTING_IP=$(grep "${10}" /etc/libvirt/qemu/installed-guests.csv | awk -F"," '{print $3}')
		if [[ -z "$9" ]]; then
			echo "${E}You didn't define static ip address, which is mandatory for default-nat-static network.${R}"
			echo "${I}Please select available IP address from the following range: 172.17.0.2 - 172.17.0.254 .${R}"
			exit 1
		elif [[ "$CORRECT_IP" != "${10}" ]]; then
			echo "${E}Incorrect static IP address defined.${R}"
			echo "${I}Please select available IP address from the following range: 172.17.0.2 - 172.17.0.254 .${R}"
			exit 1
		elif [[ "$EXISTING_IP" == "${10}" ]]; then
			echo "${E}Selected IP is already used by another guest${R}"
			echo "${I}Execute \"$0 -l\" to see which IP addresses are already taken.${R}"
			exit 1
		else
			sed -i "s@d-i netcfg/get_ipaddress string IPADDR@d-i netcfg/get_ipaddress string ${10}@g" /tmp/preseed.cfg
		fi
	else
		echo "${I} Network default-nat-dhcp selected, continuing.${R}"
	fi

	# Prepare late-install script
	cp /etc/libvirt/qemu/late-install/basic-firewall /home/webfs/htdocs/rules.v4
	chown nobody:nogroup /home/webfs/htdocs/rules.v4
	cp /etc/libvirt/qemu/late-install/debian-server-late-install.sh /home/webfs/htdocs/debian-server-late-install.sh
	sed -i "s|GATEWAY|$HOST_GATEWAY|g" /home/webfs/htdocs/debian-server-late-install.sh
	sed -i "s|HYPER_SSH_ROOT_KEY|$HOST_ROOT_KEY|g" /home/webfs/htdocs/debian-server-late-install.sh
	if [[ "$7" == "default-nat-static" ]]; then
		sed -i '/^# DHCP - START/,/^# DHCP - END/{//!d}' /home/webfs/htdocs/debian-server-late-install.sh
	fi
	if [[ -z "$SUDO_USER" ]]
	then
		echo "${I}Only root is detected, will set host root SSH key only.${R}"
	else
		HOST_USER_KEY=$(cat /home/"$SUDO_USER"/.ssh/id_rsa.pub)
		sed -i "/HYPER_SSH_USER_KEY/s/^#//g" /home/webfs/htdocs/debian-server-late-install.sh
		sed -i "s|HYPER_SSH_USER_KEY|$HOST_USER_KEY|g" /home/webfs/htdocs/debian-server-late-install.sh
	fi
	chown nobody:nogroup /home/webfs/htdocs/debian-server-late-install.sh

	# Create virtual disk
	qemu-img create -f qcow2 -o preallocation=metadata /home/libvirt/vm_images/"$2".qcow2 "$3"M

	# Check distribution
	if [[ "$SET_DISTRO" -gt "11" ]]; then
		sed -i "s@#d-i apt-setup/non-free-firmware boolean true@d-i apt-setup/non-free-firmware boolean true@g" /tmp/preseed.cfg
	fi

	# Set BIOS mode
	if [[ "$9" == "uefi" ]]; then
		BOOT_MODE="--boot firmware=efi,firmware.feature0.enabled=no,firmware.feature0.name=secure-boot"
	else
		BOOT_MODE="--boot cdrom,hd"
	fi

	# Start the installation
	virt-install --connect qemu:///system -n "$2" \
	-r "$4" \
	--vcpus "$5" \
	--cpu host \
	--machine q35 \
	--location http://ftp.debian.org/debian/dists/"$6"/main/installer-amd64/ \
	--osinfo detect=on,require=off \
	$BOOT_MODE \
	--disk path=/home/libvirt/vm_images/"$2".qcow2,bus=scsi,cache=writeback,discard=unmap,format=qcow2 \
	--console pty,target_type=serial \
	--initrd-inject=/tmp/preseed.cfg \
	--extra-args 'console=ttyS0,115200n8 serial' \
	--controller type=scsi,model=virtio-scsi \
	-w network="$7",model=virtio \
	--graphics=none \
	--virt-type kvm \
	--video=virtio \
	--memballoon virtio \
	--noreboot

	# Enable VNC Console
	virt-xml "$2" --define --add-device --graphics vnc,port=-1,listen=0.0.0.0

	# Start guest
	sleep 5
	virsh start "$2"
	sleep 15

	# Populate /etc/libvirt/qemu/installed-guests.csv
	if [[ "$7" == "default-nat-dhcp" ]]; then
		DHCP_GUEST_IP=$(virsh domifaddr --source agent "$2" | grep eth0 | awk '{print $4}' | cut -d"/" -f1)
		echo "$2,$8,$DHCP_GUEST_IP,$7" >> /etc/libvirt/qemu/installed-guests.csv
	else
		echo "$2,$8,${10},$7" >> /etc/libvirt/qemu/installed-guests.csv
	fi

	# Reset screen
	reset

	# Delete resources
	rm -rf /home/webfs/htdocs/*

	# Summary message
	VNC_PORT=$(virsh vncdisplay "$2" | tr -d ":")

	if [[ "$7" == "default-nat-dhcp" ]]; then
	cat <<-END

		${SPACER}

		  ${B}** GUEST $2 WITH DEBIAN $6 IS NOW UP AND RUNNING **${R}

		  HOSTNAME: $2
		  NETWORK: $7
		  IP ADDRESS: $DHCP_GUEST_IP
		  ROOT PASSWORD: $8
		  VNC HOST: $HOST_GATEWAY
		  VNC PORT: 590$VNC_PORT	  

		${SPACER}

		  ${B}** GUEST LOCALES **${R}

		  Default locales for guest $2 are set to ${B}en_US.UTF-8${R}. If you need to set
		  additional locales, please run ${B}dpkg-reconfigure locales${R} and select
		  locales you require.

		${SPACER}

		  ${B}** GUEST TIME ZONE **${R}

		  Default time zone for guest $2 is set to ${B}UTC${R}. If you need to change time zone,
		  please run ${B}dpkg-reconfigure tzdata${R} and select the required time zone.

		${SPACER}

	END
	else
	cat <<-END

		${SPACER}

		  ${B}** GUEST $2 WITH DEBIAN $6 IS NOW UP AND RUNNING **${R}

		  HOSTNAME: $2
		  NETWORK: $7
		  IP ADDRESS: ${10}
		  ROOT PASSWORD: $8
		  VNC HOST: $HOST_GATEWAY
		  VNC PORT: 590$VNC_PORT	  

		${SPACER}

		  ${B}** GUEST LOCALES **${R}

		  Default locales for guest $2 are set to ${B}en_US.UTF-8${R}. If you need to set
		  additional locales, please run ${B}dpkg-reconfigure locales${R} and select locales you require.

		${SPACER}

		  ${B}** GUEST TIME ZONE **${R}

		  Default time zone for guest $2 is set to ${B}UTC${R}. If you need to change time zone,
		  please run ${B}dpkg-reconfigure tzdata${R} and select the required time zone.

		${SPACER}

	END
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
while getopts ":hlsni" option; do
	case $option in
		h) # Display help message
			setOptions
			exit
			;;
		l) # List existing guest machines
			systemChecks
			listExistingGuests
			exit
			;;
		s) # List supported Debian distributions
			listSupportedDistros
			exit
			;;
		n) # List available networks info
			systemChecks
			availableNetworks
			exit
			;;
		i) # Install Debian guest machine
			systemChecks
			installDebianServer "$@"
			exit
			;;
		\?) # Invalid options
			echo "Invalid option, will exit now."
			exit
			;;
	esac
done
