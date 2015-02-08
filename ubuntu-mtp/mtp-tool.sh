#!/bin/bash

set -o nounset

ASSUME_YES=false
DO_THINGS=false
FIRST_TIME=false

function getargs(){
	local OPTIND
	while getopts ":fhiy" opt; do
		case ${opt} in
		f)
			DO_THINGS=true;;
		h)
			getHelp
			exit 0;;
		i)
			FIRST_TIME=true;;
		y)
			ASSUME_YES=true;;
		:)
			exec >&2
			printf "Option -${OPTARG} requires an argument\n\n"
			set -f
			getHelp | grep "[[:blank:]]*-${OPTARG}"
			set +f
			exit 1;;
		\?)
			exec >&2
			printf "Unknown flag -${OPTARG}\n\n"
			printf "Allowed flags:\n"
			getHelp | awk '/[[:blank:]]+-[[:alpha:]]/'
			exit 1;;
		esac
	done
	return ${OPTIND}
}

function getHelp() {
	printf "Usage:\t$( basename ${0} )\n"
	printf "Options\n"
	printf "   -f: Force do things (or else this script merely returns information)\n"
	printf "   -h: Displays this help message\n"
	printf "   -i: Runs through the first-time setup (installing packages)\n"
	printf "   -y: Assumes yes to everything\n"
}

function error() {
	printf "[ERROR]\t${@}\n\nRefusing to continue...\n" >&2
	exit 1
}

function warn() {
	printf "[WARN]\t${@}\n"
}

function info() {
	printf "[INFO]\t${@}\n"
}

function yesno() {
	printf "${@}"
	${ASSUME_YES} && { printf "y"; return 0; }
	while read -n 1 LINE_IN; do
		case ${LINE_IN} in
			[Yy] ) return 0;;
			[Nn] ) return 1;;
			* ) ;; # printf "\nPlease input (y)es or (n)o:\t"
		esac
	done
}

function firstTime() {
	info "Running through first-time setup"
	local FUSE_FILE="/etc/fuse.conf"
	if sudo ls "${FUSE_FILE}" &> /dev/null; then
		if [[ ! -r ${FUSE_FILE} ]]; then
			info "Granting read-all permissions to '${FUSE_FILE}'"
			sudo chmod a+r ${FUSE_FILE}
		fi
		info "Editing '${FUSE_FILE}' to allow other users to access root-mounted partitions"
		sudo sed -i 's/^#\+\s*\(user_allow_other\)/\1/' ${FUSE_FILE}
	else
		warn "Skipping editing file becasue file not found: '${FUSE_FILE}'"
	fi

	info "Adding PPA for latest 'mtp-tools' and 'go-mtpfs' binaries"
	sudo add-apt-repository -y ppa:webupd8team/unstable > /dev/null
	info "Updating apt-get caches"
	sudo apt-get update > /dev/null
	info "Installing 'mtp-tools' and 'go-mtpfs'"
	sudo apt-get -y install mtp-tools go-mtpfs > /dev/null
	info "Removing PPA for latest 'mtp-tools' and 'go-mtpfs' binaries"
	sudo add-apt-repository -y --remove ppa:webupd8team/unstable > /dev/null
	info "Updating apt-get caches"
	sudo apt-get update > /dev/null

	binariesCheck
}

function binariesCheck() {
	info "Checking for latest binaries"
	local MTP_TOOLS_VERSION=$( dpkg-query -W -f='${Version}\n' mtp-tools )
	info "mtp-tools version: ${MTP_TOOLS_VERSION}"
	if [[ $( echo ${MTP_TOOLS_VERSION} | sed  -r 's/^([[:digit:]])\.([[:digit:]])\.([[:digit:]]).*/\1\2\3/' ) < 115 ]]; then
		error "mtp-tools version must be at least 1.1.5"
	fi
	local GO_MTPFS_VERSION=$( dpkg-query -W -f='${Version}\n' go-mtpfs )
	info "go-mtpfs version: ${GO_MTPFS_VERSION}"
	if [[ $( echo ${GO_MTPFS_VERSION} | sed  -r 's/^([[:digit:]])\.([[:digit:]])-([[:digit:]]).*/\1\2\3/' ) < 011 ]]; then
		error "go-mtpfs version must be at least 0.1-1"
	fi
}

function deviceInfo() {
	info "Getting device information"
	local DEVICES_LIST=($( sudo mtp-detect 2>&1 | grep -E '@ bus [[:digit:]]+, dev [[:digit:]]+' | awk '/[[:alnum:]]+:[[:alnum:]]+/{print $1 }' ))
	local count=0
	for DEVICE in ${DEVICES_LIST[*]}; do
		info "Device ${count}"
		local VENDOR_ID=$( echo ${DEVICE} | cut -d ':' -f 1 )
		info "   Vendor ID : ${VENDOR_ID}"
		local DEVICE_ID=$( echo ${DEVICE} | cut -d ':' -f 2 )
		info "   Device ID : ${DEVICE_ID}"
		local BUS=$( lsusb | grep -F "${VENDOR_ID}:${DEVICE_ID}" | awk '{ print $2; }' )
		info "   Bus       : ${BUS}"
		local DEVICE=$( lsusb | grep -F "${VENDOR_ID}:${DEVICE_ID}" | awk '{ print substr($4, 0, length($4)-1) }' )
		info "   Device    : ${DEVICE}"
		local PCI_PATH=$( udevadm info --query=path --name=/dev/bus/usb/${BUS}/${DEVICE} )
		info "   PCI Path  : ${PCI_PATH}"
		local ID_VENDOR=$( udevadm info --export --query=property --path=${PCI_PATH} | grep '^ID_VENDOR=' | cut -d '=' -f 2 | sed "s/'//g" )
		info "   ID Vendor : ${ID_VENDOR}"
		local ID_MODEL=$( udevadm info --export --query=property --path=${PCI_PATH} | grep '^ID_MODEL=' | cut -d '=' -f 2 | sed "s/'//g" )
		info "   ID Model  : ${ID_MODEL}"

		let "count += 1"

		! ${DO_THINGS} && continue
		yesno "\nSet up Device $(( ${count}-1 ))? " || { printf "\n"; continue; }
		local MOUNT_PT="/media/${ID_MODEL}"
		yesno "\n\tCreate mount-point '${MOUNT_PT}'? " && createMountPoint ${MOUNT_PT}
		local UDEV_RULE_FILE="/etc/udev/rules.d/99-mtp-${ID_MODEL}-${VENDOR_ID}-${DEVICE_ID}.rules"
		yesno "\n\tCreate udev-rule file '${UDEV_RULE_FILE}'? " && createUdevRuleFile ${UDEV_RULE_FILE} ${ID_MODEL} ${VENDOR_ID} ${DEVICE_ID} ${MOUNT_PT}
		yesno "\n\tRe-load udev rules? " && ! reloadUdev ${UDEV_RULE_FILE} && continue
		local USB_HOST=$( echo ${PCI_PATH} | cut -d '/' -f 4 )
		printf "\n\n"
		info "Resetting USB host '${USB_HOST}' to trigger auto-mount"
		echo -n "${USB_HOST}" | sudo tee /sys/bus/pci/drivers/ehci_hcd/unbind > /dev/null
		echo -n "${USB_HOST}" | sudo tee /sys/bus/pci/drivers/ehci_hcd/bind > /dev/null
		info "Sleeping 2sec to wait for device to auto-mount"
		sleep 2s
		mount | grep -q "^DeviceFs(${ID_MODEL})" && info "Success!" || warn "Failed!"
	done
}

function createMountPoint() {
	local MOUNT_PT=${1}
	sudo mkdir -p ${MOUNT_PT} && sudo chown root:root ${MOUNT_PT} && sudo chmod 777 ${MOUNT_PT}
	if [[ ${?} -eq 0 ]]; then
		printf " ............done"
		return 0
	else
		printf "\n"
		warn "Couldn't successfully create mount point '${MOUNT_PT}'"
		return 1
	fi
}

function createUdevRuleFile() {
	set -o nounset
	local FILE=${1}
	local ID_MODEL=${2}
	local ID_VENDOR=${3}
	local ID_PRODUCT=${4}
	local MOUNT_PT=${5}
	local NONROOT_USER=$( whoami )
	[[ -d $( dirname ${FILE} ) ]] || { printf "\n"; warn "Parent directory '$( dirname ${FILE} )' should exist but doesn't"; return 1; }
	sudo touch ${FILE} || return 1
	echo "# ${ID_MODEL} - MTP mount & unmount rules" | sudo tee ${FILE} > /dev/null
	printf "SUBSYSTEM==\"usb\", ATTR{idVendor}==\"${ID_VENDOR}\", ATTR{idProduct}==\"${ID_PRODUCT}\", " | sudo tee -a ${FILE} > /dev/null
	printf "MODE=\"0666\", OWNER=\"${NONROOT_USER}\"\n" | sudo tee -a ${FILE} > /dev/null
	printf "ENV{ID_MODEL}==\"${ID_MODEL}\", ENV{ID_MODEL_ID}==\"${ID_PRODUCT}\", ACTION==\"add\", " | sudo tee -a ${FILE} > /dev/null
	printf "RUN+=\"/usr/bin/sudo -b -u ${NONROOT_USER} /usr/bin/go-mtpfs -dev=${ID_VENDOR}:${ID_PRODUCT} -allow-other=true ${MOUNT_PT}\"\n" | sudo tee -a ${FILE} > /dev/null
	printf "ENV{ID_MODEL}==\"${ID_MODEL}\", ENV{ID_MODEL_ID}==\"${ID_PRODUCT}\", ACTION==\"remove\", RUN+=\"/bin/umount ${MOUNT_PT}\"\n" | sudo tee -a ${FILE} > /dev/null
	printf " ............done"
	return 0
}

function reloadUdev() {
	local UDEV_RULE_FILE=${1}
	sudo service udev restart 2>&1 | grep -q '[[:digit:]]\+$' && { printf " ............done"; return 0; }
	printf "\n"
	warn "udev service failed to restart successfully"
	warn "Removing possibly corrupted file '${UDEV_RULE_FILE}'"
	sudo rm ${UDEV_RULE_FILE}
	warn "Restarting udev"
	sudo service udev restart
	warn "Skipping this device"
	return 1
}

# Parses flags
getargs "${@}"

# This section does general checks
[[ "$( sudo whoami )" != "root" ]] && error "Insufficient privileges!"

${FIRST_TIME} && firstTime || binariesCheck

deviceInfo
