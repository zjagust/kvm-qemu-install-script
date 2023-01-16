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
		${B}https://github.com/zjagust ${R}
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
	if [ "$CONFIG_VIRTIO_MOD" == my ] || [ "$CONFIG_VIRTIO_MOD" == ym ];
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
			echo "${B}executing the following commands: \"echo 35 > /proc/sys/vm/swappiness\" and \"sed -i "\\\$a# Set swappiness\\nvm.swappiness=35" /etc/sysctl.conf\"${R}"
	elif [ "$IS_DESKTOP" == false ] && [ "$RAM_IN_GB" -le 16 ];
		then
			echo "${B}You're running a Server system with 16BG or less RAM. You can set swappiness on 35 by${R}"
			echo "${B}executing the following commands: \"echo 35 > /proc/sys/vm/swappiness\" and \"sed -i "\\\$a# Set swappiness\\nvm.swappiness=35" /etc/sysctl.conf\"${R}"
	else
		echo "${B}You're running a Server system with at least 16 GB RAM. If you're running services other than KVM and QEMU,${R}"
		echo "${B}you can set swappiness on 30. If this is a dedicated KVM QEMU server, you can set swappiness on 1${R}"
		echo "${B}(i.e., \"echo 1 > /proc/sys/vm/swappiness\" and \"sed -i "\\\$a# Set swappiness\\nvm.swappiness=1" /etc/sysctl.conf\").${R}"
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
	apt install -y bridge-utils \
	libvirt-clients \
	libvirt-daemon \
	qemu \
	qemu-system-x86 \
	qemu-utils \
	virtinst

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

	# Display install info message
	echo "${SPACER}"
	echo "${I}## INSTALLATION COMPLETE ##${R}"
	echo "${SPACER}"
	echo "For any additional information, please visit:"
	echo "${B}https://github.com/zjagust ${R}"
	echo "${B}https://zacks.eu/kvm-qemu-installation-configuration ${R}"
	echo "${SPACER}"
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
while getopts ":hrnzsdi" option; do
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
			exit
			;;
		\?) # Invalid options
			echo "Invalid option, will exit now."
			exit
			;;
	esac
done