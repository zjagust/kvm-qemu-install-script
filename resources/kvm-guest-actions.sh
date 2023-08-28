#!/usr/bin/env bash

#######################################################################################################
#
# Zack's - KVM Guest Actions
# Version: 1.0
#
# This script will perform various actions on KVM guest machines like snapshot manipulation, state
# change and instance removal.
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
		${B}${I}KVM GUEST ACTIONS SCRIPT${R}
		${I}This script has multiple options.${R}
		${SPACER}
		The following options are available:
		 ${B}-H:${R} Print this help message
		 ${B}-S:${R} Change guest state
		  -Sd to show GUEST_NAMES
		  -Ss GUEST_NAME to start guest
		  -Sh GUEST_NAME to shutdown guest
		  -Sr GUEST_NAME to reboot guest
		  -Sp GUEST_NAME to completely purge guest
		   -> (usage: $0 [-Ss] [-Sh] [-Sr] [-Sp] GUEST_NAME 
		   ->         $0 [-Sd])
		 ${B}-D:${R} Display/Create/Apply/Delete guest snapshot
		  -Di GUEST_NAME to list snapshots and SNAPSHOT_TAG
		  -Dc GUEST_NAME SNAPSHOT_NAME to create snapshot
		  -Da GUEST_NAME SNAPSHOT_TAG to apply snapshot
		  -Dd GUEST_NAME SNAPSHOT_TAG to delete shapshot
		   -> (usage: $0 [-Di] GUEST_NAME 
		   ->         $0 [-Dc] GUEST_NAME SNAPSHOT_NAME 
		   ->         $0 [-Da] [-Dd] GUEST_NAME SNAPSHOT_TAG)
		 ${B}-V:${R} Display/Create&Attach/Attach/Detach/Delete guest virtual drives
		  -Vl GUEST_NAME to list attached virtual drives
		  -Vc GUEST_NAME IMAGE_NAME IMAGE_SIZE (in MiB) to create and optionally attach a new virtual disk
		  -Va GUEST_NAME to attach already existing image from default pool
		  -Vd GUEST_NAME to detach disk image
		  -Vp to delete virtual disk
		   -> (usage: $0 [-Vl] [-Va] [-Vd] GUEST_NAME 
		   ->         $0 [-Vc] GUEST_NAME IMAGE_NAME IMAGE_SIZE (in MiB)
		              $0 [-Vp])
		 ${B}-N:${R} Display guest network info (interfaces/MACs/IPs)
		  -N GUEST_NAME name to list active interface(s) info
		   -> (usage: $0 [-N] GUEST_NAME)
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

	# System Checks Footer
	echo "${SPACER}"

}

#################
## GUEST CHECK ##
#################

function guestCheck () {

		# Check if guest exists
		GUEST_EXISTS=$(virsh list --all | grep "$2")
		if [[ -z "$GUEST_EXISTS" ]]; then
			echo
			echo "${E}Guest $2 does not exist. Available guests are:${R}"
			virsh list --all
			echo "${SPACER}"
			exit 1
		fi
	}

########################
## CHANGE GUEST STATE ##
########################

function guestState () (

	
	function displayCurrentGuestState () {

		# Display current state of all guests
		echo "${B}** CURRENT STATE OF ALL GUESTS **${R}"
		echo "${SPACER}"
		echo
		virsh list --all
		echo "${SPACER}"
		echo

	}

	function guestStart () {

		#Start guest
		guestCheck "$@"
		echo "${B} ** STARTING GUEST $2 ** ${R}"
		echo "${SPACER}"
		echo
		virsh start "$2"
		echo "${SPACER}"
		echo

	}

	function guestStop () {

		#Start individual guest
		guestCheck "$@"
		echo "${B} ** STOPPING GUEST $2 ** ${R}"
		echo "${SPACER}"
		echo
		virsh destroy "$2"
		echo "${SPACER}"
		echo

	}

	function guestReboot () {

		#Start individual guest
		guestCheck "$@"
		echo "${B} ** REBOOTING GUEST $2 ** ${R}"
		echo "${SPACER}"
		echo
		virsh reboot "$2"
		echo "${SPACER}"
		echo

	}

	function guestPurge () {

		# Confirm purge individual guest
		guestCheck "$@"
		local PURGE_GUEST
		echo "${B}** PURGE GUEST $2 **${R}"
		echo "${SPACER}"
		echo
		echo "${W}This action will completely purge guest $2 and all belonging images.${R}"
		read -rp "Please type ${B}y${R} to confirm you really want to purge guest $2, or press Enter to cancle: ${B}" PURGE_GUEST
		echo "${R}"

		# Purge individual guest
		if [[ "$PURGE_GUEST" == y ]]; then
			echo "$SPACER"
			echo "${B}** PURGING GUEST $2 **${R}"
			echo "$SPACER"
			if [[ "$(virsh list --all | grep "$2" | awk '{print $3}')" == running ]]; then
				virsh destroy "$2"; virsh undefine --remove-all-storage "$2"
			else
				virsh undefine --remove-all-storage "$2"
			fi
			# Delete from inventory
			if [[ -f /etc/libvirt/qemu/installed-guests.csv ]]; then
				sed -i "/$2/d" /etc/libvirt/qemu/installed-guests.csv
			fi
			echo "${I}Guest $2 successfully purged.${R}"
			echo "${SPACER}"
		else
			echo "${SPACER}"
			echo "${I}Action canceled.${R}"
			echo "${SPACER}"
		fi

	}

	while getopts ":dshrp" option; do
		case $option in
			d) # Display guest state
				displayCurrentGuestState
				exit
				;;
			s) # Start guest
				guestStart "$@"
				exit
				;;
			h) # Shutdown guest
				guestStop "$@"
				exit
				;;
			r) # Reboot guest
				guestReboot "$@"
				exit
				;;

			p) # Purge guest
				guestPurge "$@"
				exit
				;;
			\?) # Invalid options
				echo "Invalid option, will exit now."
				exit
				;;
		esac
	done

)

function guestSnapshot () (

	# Check if guest is running
	if [[ "$(virsh list --all | grep "$2" | awk '{print $3}')" == running ]]
	then
		echo "${B} ** GUEST IS RUNNING ** ${R}"
		echo "${SPACER}"
		echo
		echo "${E}Guest $2 is running, unable to perform snapshot actions.${R}"
		echo
		echo "${SPACER}"
		exit 1
	fi

	# Set snapshot path
	PATH=$(virsh domblklist "$2" --details | grep sda | awk '{print $4}')

	function guestSnapshotInfo () {
		
		# Check snapshot info
		echo "${B} ** SYSTEM DISK SNAPSHOTS FOR GUEST $1 ** ${R}"
		echo "${SPACER}"
		/usr/bin/qemu-img snapshot -l "$PATH"
		echo "${SPACER}"
		echo
		
	}

	function guestSnapshotCreate () {

		# Create snapshot
		echo "${B} ** CREATING SYSTEM DISK SNAPSHOT FOR GUEST $1 ** ${R}"
		echo "${SPACER}"
		/usr/bin/qemu-img snapshot -c "$2" "$PATH"
		if [[ $? == 0 ]]; then
			echo "${I}Snapshot $2 created successfully.${R}"
		else
			echo "${E}Snapshot failed, something went wrong :/${R}"
		fi
		echo "${SPACER}"
		echo

	}

	function guestSnapshotApply () {

		# Apply snapshot
		echo "${B} ** APPLY SYSTEM DISK SNAPSHOT FOR GUEST $1 ** ${R}"
		echo "${SPACER}"
		/usr/bin/qemu-img snapshot -a "$2" "$PATH"
		if [[ $? == 0 ]]; then
			echo "${I}Snapshot $2 applied successfully.${R}"
		else
			echo "${E}Snapshot apply failed, something went wrong :/${R}"
		fi
		echo "${SPACER}"
		echo

	}

	function guestSnapshotDelete () {

		# Delete snapshot
		echo "${B} ** DELETE SYSTEM DISK SNAPSHOT FOR GUEST $1 ** ${R}"
		echo "${SPACER}"
		/usr/bin/qemu-img snapshot -d "$2" "$PATH"
		if [[ $? == 0 ]]; then
			echo "${I}Snapshot $2 deleted successfully.${R}"
		else
			echo "${E}Snapshot delete failed, something went wrong :/${R}"
		fi
		echo "${SPACER}"
		echo

	}

	while getopts ":icad" option; do
		case $option in
			i) # Display snapshot info
				guestSnapshotInfo "$2"
				exit
				;;
			c) # Create snapshot
				guestSnapshotCreate "$2" "$3"
				exit
				;;
			a) # Apply snapshot
				guestSnapshotApply "$2" "$3"
				exit
				;;
			d) # Delete snapshot
				guestSnapshotDelete "$2" "$3"
				exit
				;;
			\?) # Invalid options
				echo "Invalid option, will exit now."
				exit
				;;
		esac
	done
)

function guestDisk () (

	# Set images path
	IMAGES_PATH=$(virsh pool-dumpxml default |grep -i path | sed 's/<path>//;s/<\/path>//g' | tr -d " \t\r")
	IMAGES_SHEET="/etc/libvirt/qemu/guest_storage_list.xsl"

	function listAttachedImages () {

		# List attached images
		echo "${B} ** IMAGES CURRENTLY ATTACHED TO GUEST $1 ** ${R}"
		echo "${SPACER}"
		echo
		virsh domblklist "$1" --details
		echo "${SPACER}"
		echo

	}

	function createNewImage () {

		# Check if image already exists
		if [[ -f "$IMAGES_PATH"/"$2" ]]; then
			echo "${E} ** IMAGE EXISTS ** ${R}"
			echo "${SPACER}"
			echo "${E}Image $2 already exists, will abort now.${R}"
			echo "${SPACER}"
			echo
			exit 1
		else
			# Create new image in default pool
			echo "${B} ** CREATING $IMAGES_PATH/$2 IMAGE  ** ${R}"
			echo "${SPACER}"
			qemu-img create -f qcow2 -o preallocation=metadata "$IMAGES_PATH"/"$2" "$3"
			echo "${SPACER}"
		fi

		# Attach also
		local ATTACH_IMAGE_ALSO
		echo "${B} ** ATTACH $IMAGES_PATH/$2 IMAGE TO $1 GUEST ALSO?  ** ${R}"
		echo "${SPACER}"
		echo
		read -rp "Type ${B}y${R} if you also want to attach image to guest $1: ${B}" ATTACH_IMAGE_ALSO
		echo "${R}"

		# Check if guest is running
		if [[ "$(virsh list --all | grep "$1" | awk '{print $3}')" == running ]]; then
			if [[ "$ATTACH_IMAGE_ALSO" != y ]]; then
				echo "${SPACER}"
				echo "${I}Image $2 will not be attached.${R}"
				echo "${SPACER}"
			else
				# Set target
				NEW_TARGET=$(virsh domblklist "$1" --details | sed '/^$/d' | tail -n1 | awk '{print $3}' | tail -c 2 | tr '[:lower:]' b-za)
				# Attach disk
				echo "${SPACER}"
				echo
				virsh attach-disk "$1" "$IMAGES_PATH"/"$2" sd"$NEW_TARGET" --cache writeback --persistent
				echo "${SPACER}"
			fi
		else
			echo "${SPACER}"
			echo "${E} ** UNABLE TO ATTACH IMAGE ** ${R}"
			echo "${SPACER}"
			echo "${E}Unable to attach image, guest $1 is not running. Will exit now${R}"
			echo "${SPACER}"
			exit 1
		fi

	}

	function attachImage () {

		# List already attached images
		listAttachedImages "$1"

		# List all available images in default pool/path
		echo "${B} ** AVAILABLE IMAGES IN DEFAULT POOL $IMAGES_PATH ** ${R}"
		echo
		echo "${SPACER}"
		echo "${I}Listing all images in default pool/path $IMAGES_PATH: ${R}"
		find "$IMAGES_PATH" -type f -name "*.qcow2" |cut -d"/" -f4

		# List all currently used images
		echo "${SPACER}"
		echo "${B} ** LIST ALL CURRENTLY ATTACHED IMAGES ON ALL GUESTS ** ${R}"
		echo "${SPACER}"
		pushd /etc/libvirt/qemu > /dev/null || exit
			for IMAGES_USED in *.xml; do
				basename "$IMAGES_USED" .xml
				xsltproc $IMAGES_SHEET "$IMAGES_USED"
			done
		popd > /dev/null || exit

		# Set target
		NEW_TARGET=$(virsh domblklist "$1" --details | sed '/^$/d' | tail -n1 | awk '{print $3}' | tail -c 2 | tr '[:lower:]' b-za)
		
		# Select image
		echo "${SPACER}"
		echo "${B} ** SELECT IMAGE TO ATTACH FROM DEFAULT POOL $IMAGES_PATH ** ${R}"
		echo "${SPACER}"
		echo
		echo "${W}Make sure the image you want to attach is not in currently attached images list above!${R}"
		read -rp "Type in the name of the image (from available images list above) you want to attach to guest $1: ${B}" ATTACH_NEW_IMAGE
		echo "${R}"

		# Attach image
		echo "${SPACER}"
		echo "${B} ** ATTACH $ATTACH_NEW_IMAGE TO $1 GUEST ** ${R}"
		echo "${SPACER}"
		echo
		virsh attach-disk "$1" "$IMAGES_PATH"/"$ATTACH_NEW_IMAGE" sd"$NEW_TARGET" --cache writeback --persistent
		echo "${SPACER}"

	}

	function detachImage () {

		# List already attached images
		listAttachedImages "$1"

		# Select image to detach
		echo "${B} ** SELECT IMAGE TO DETACH FROM $1 GUEST ** ${R}"
		echo "${SPACER}"
		echo
		read -rp "Type in the name of the image you want to detach from $1 guest from the list above: ${B}" DETACH_IMAGE
		echo "${R}"

		# Permanent or not
		echo "${SPACER}"
		echo "${B} ** DETACH IMAGE FROM $1 GUEST PERMANENTLY? ** ${R}"
		echo "${SPACER}"
		echo
		read -rp "Type ${B}y${R} to detach $DETACH_IMAGE from guest $1 permanently: ${B}" DETACH_PERMANENTLY
		echo "${R}"

		# Check if system disk
		SYSTEM_DISK=$(virsh domblklist "$1" --details | grep sda | awk '{print $4}')
		if [[ "$DETACH_IMAGE" == "$SYSTEM_DISK" ]]; then
			echo "${SPACER}"
			echo "${E}!! Cannot detach image $DETACH_IMAGE because it is $1 guest system disk !!${R}"
			echo "${SPACER}"
			exit 1
		fi
		
		# Detach image
		if [[ "$DETACH_PERMANENTLY" == y ]]; then
			echo "${SPACER}"
			echo
			virsh detach-disk "$1" "$DETACH_IMAGE" --persistent
			echo "${SPACER}"
		else
			echo "${SPACER}"
			echo
			virsh detach-disk "$1" "$DETACH_IMAGE"
			echo "${SPACER}"
		fi

		# Delete also
		local DELETE_IMAGE_ALSO
		echo "${SPACER}"
		echo "${B} ** DELETE IMAGE $DETACH_IMAGE ALSO? ** ${R}"
		echo
		read -rp "Type ${B}y${R} if you want to delete $DETACH_IMAGE virtual disk also: ${B}" DELETE_IMAGE_ALSO
		echo "${R}"

		if [[ "$DELETE_IMAGE_ALSO" != y ]]; then
			echo "${SPACER}"
			echo "${I}Image $DETACH_IMAGE will not be deleted.${R}"
			echo "${SPACER}"
		else
			rm -rf "$DETACH_IMAGE"
			echo "${SPACER}"
			echo "${I}Deleting Image $DETACH_IMAGE also.${R}"
			echo "${SPACER}"
		fi

	}

	function deleteImage () {

		# List all available images in default pool/path
		echo "${B} ** AVAILABLE IMAGES IN DEFAULT POOL $IMAGES_PATH ** ${R}"
		echo "${SPACER}"
		echo "${I}Listing all images in default pool/path $IMAGES_PATH: ${R}"
		find "$IMAGES_PATH" -type f -name "*.qcow2" |cut -d"/" -f4

		# List all currently used images
		echo "${SPACER}"
		echo "${B} ** LIST ALL CURRENTLY ATTACHED IMAGES ON ALL GUESTS ** ${R}"
		echo "${SPACER}"
		pushd /etc/libvirt/qemu > /dev/null || exit
			for IMAGES_USED in *.xml; do
				basename "$IMAGES_USED" .xml
				xsltproc $IMAGES_SHEET "$IMAGES_USED"
			done
		popd > /dev/null || exit

		# Select and delete image
		local DELETE_IMAGE
		echo "${SPACER}"
		echo "${B} ** DELETE IMAGE  ** ${R}"
		echo "${SPACER}"
		echo
		echo "${W}Make sure the image you want to delete is not in currently attached images list above!${R}"
		read -rp "Please type in the name of the image which you want to delete from the available images list above: ${B}" DELETE_IMAGE
		echo "${R}"
		
		# Attachement check variable
		ATTACHED_IMAGES=$(virsh list --all | tail -n +3 | awk '{print $2}' | tr "\n" " ")
		LIVE_ATTACHEMENT=$(for IMAGES in $ATTACHED_IMAGES; do virsh domblklist "$IMAGES" --details | tail -n +3 | awk '{print $4}'; done | grep "$DELETE_IMAGE")
		
		if [[ "$LIVE_ATTACHEMENT" == "$IMAGES_PATH"/"$DELETE_IMAGE" ]]; then
			echo "${SPACER}"
			echo "${E}The image $DELETE_IMAGE is currently attached to virtual machine. It will not be deleted.${R}"
			echo "${I}Please reference currently attached images list above to see which one exactly.${R}"
			echo "${SPACER}"
			exit 1
		else
			rm -rf "${IMAGES_PATH:?}"/"$DELETE_IMAGE"
			echo "${SPACER}"
			echo "${I}Image $DELETE_IMAGE is now deleted.${R}"
			echo "${SPACER}"
		fi
		
	}

	while getopts ":lcadp" option; do
		case $option in
			l) # List attached images
				listAttachedImages "$2"
				exit
				;;
			c) # Create new virtual disk
				createNewImage "$2" "$3" "$4"
				exit
				;;
			a) # Attach virtual disk
				attachImage "$2"
				exit
				;;
			d) # Detach virtual disk
				detachImage "$2"
				exit
				;;
			p) # Delete virtual disk
				deleteImage
				exit
				;;
			\?) # Invalid options
				echo "Invalid option, will exit now."
				exit
				;;
		esac
	done

)

function basicNetwork () (

	# Check if guest is running
		if [[ "$(virsh list --all | grep "$2" | awk '{print $3}')" != running ]]
		then
			echo "${E}Guest $2 is shut off, unable to get network info.${R}"
			echo "${SPACER}"
			exit 1
		fi

	# Set default check
	GUEST_NET_CHECK=$(virsh domifaddr "$2" | tail -n +3)
	GUEST_NET_CHECK_ARP=$(virsh domifaddr --source arp "$2" | tail -n +3)
	GUEST_NET_CHECK_AGENT=$(virsh domifaddr --source agent "$2" | tail -n +3)

	# Display guest network info
	if [[ -n "$GUEST_NET_CHECK" ]]; then
		GUEST_NET_DEFAULT=$(virsh domifaddr "$2")
		echo "${B}** USING DEFAULT METHOD TO DISPLAY NETWORK INFO FOR $2 GUEST. **${R}"
		echo "${SPACER}"
		echo "$GUEST_NET_DEFAULT"
		echo "${SPACER}"
	elif [[ -n "$GUEST_NET_CHECK_ARP" ]]; then
		GUEST_NET_ARP=$(virsh domifaddr --source arp "$2")
		echo "${B}** USING ARP METHOD TO DISPLAY NETWORK INFO FOR $2 GUEST. **${R}"
		echo "${SPACER}"
		echo "$GUEST_NET_ARP"
		echo "${SPACER}"
	elif [[ -n "$GUEST_NET_CHECK_AGENT" ]]; then
		GUEST_NET_AGENT=$(virsh domifaddr --source agent "$2")
		echo "${B}** USING QEMU AGENT METHOD TO DISPLAY NETWORK INFO FOR $2 GUEST. **${R}"
		echo "${SPACER}"
		echo "$GUEST_NET_AGENT"
		echo "${SPACER}"
	else
		echo "${E}No more methods to check, something is worng with network.${R}"
		echo "${SPACER}"
		exit 1
	fi

)

#################
## GET OPTIONS ##
#################

# No parameters
if [ $# -eq 0 ]; then
	setOptions
	exit 1
fi

# Execute
while getopts ":HSDVN" option; do
	case $option in
		H) # Display help
			setOptions
			exit
			;;
		S) # Change guest state
			systemChecks
			guestState "$@"
			exit
			;;
		D) # Snapshot actions
			systemChecks
			guestCheck "$@"
			guestSnapshot "$@"
			exit
			;;
		V) # Guest Disks
			systemChecks
			guestCheck "$@"
			guestDisk "$@"
			exit
			;;
		N) # Check guest network
			systemChecks
			guestCheck "$@"
			basicNetwork "$@"
			exit
			;;
		\?) # Invalid options
				echo "Invalid option, will exit now."
				exit
				;;
	esac
done