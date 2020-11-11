#!/bin/bash

TOOLS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"


. "$TOOLS_DIR/colors.sh"
. "$TOOLS_DIR/util.sh"
. "$TOOLS_DIR/tools.sh"

set -e


setup() {
	 sudo echo ""
	 log "Got sudo"
}

load_config() {
	log "Config file: $@"
	if [[ -f "$1" ]]; then
		run source $1
		run cd $(dirname $1)
	fi
}

check_vars() {
	# Check that all required variables are set in the config file
	for var in $(echo "Q_OVERLAYS_DIR Q_BUILD_DIR Q_IMG_DIR Q_SCRIPTS_DIR Q_IN_IMG Q_OUT_IMG"); do
		if [[ ! -v $var ]]; then
			echo "Missing environment variable $var"
			exit 1
		fi
	done
}

copy_image() {
	run cp $1 $2
}

expand_partition() {
	if [[ -z $Q_EXPAND_FS_SIZE_MB ]]; then return; fi
	log "Checking for ext partition"
	# Check that there is an ext* partition
	if ! sudo parted $Q_OUT_IMG <<< p 2>&1 | grep ext; then
		log "Could not find an ext2/3/4 partition on image"
		exit 1
	fi

	ROOTFS_PART_NUM=$(sudo parted $Q_OUT_IMG <<< p 2>&1 | grep ext|head -n1|sed 's/^ *//' |cut -d" " -f1)
	log "Found ext partition at position $ROOTFS_PART_NUM"
	# Expand the image first
	log "Expanding partition $ROOTFS_PART_NUM by $Q_EXPAND_FS_SIZE_MB MB"
	run dd bs=8M if=/dev/zero of=$Q_OUT_IMG count=$(($Q_EXPAND_FS_SIZE_MB/8)) status=progress oflag=sync,append conv=notrunc
	# Now grow the partition
	log "Growing the partition"
	run sudo growpart $Q_OUT_IMG $ROOTFS_PART_NUM
}

mount_img() {
	OUTPUT=$(los $Q_OUT_IMG)
	export Q_MNT_POINTS=$(echo $OUTPUT | cut -d" " -f2-)
	export Q_DEV_IMG=$(echo $OUTPUT | cut -d" " -f1)

	export Q_MNT_ROOTFS="/mnt/$(basename $Q_DEV_IMG)"p${ROOTFS_PART_NUM}
	export Q_DEV_ROOTFS="/dev/$(basename $Q_DEV_IMG)"p${ROOTFS_PART_NUM}
	log "Mounted $Q_OUT_IMG on $Q_DEV_IMG"
	log "Mounted $Q_MNT_POINTS"
}

expand_fs() {
	if [[ -n "$Q_EXPAND_FS_SIZE" ]]; then
		log "Skipping expand_fs()"
		return 0
	fi

	# Step 2 of expanding the fs
	BEFORE=$(df -h |grep -E "$Q_DEV_ROOTFS | Avail")
	log "Expanding filesystem on partition $ROOTFS_PART_NUM to fill remaining space"
	run sudo resize2fs $Q_DEV_ROOTFS
	AFTER=$(df -h |grep -E "$Q_DEV_ROOTFS")
	log "======== Size diff ==============="
	log "$BEFORE"
	log "$AFTER"
}

mount_live_binds() {
	log "Mounting live binds..."
	# https://superuser.com/a/417004
	cd $Q_MNT_ROOTFS
	run sudo mount -t proc /proc proc/
	run sudo mount --rbind /sys sys/
	run sudo mount --rbind /dev dev/
	#run sudo mount --bind /proc $Q_MNT_ROOTFS/proc
}

mount_apt_cache() {
	log "Mounting apt-cache"
	run mkdir -p $Q_CACHE_DIR

	TARGET_CACHE="$Q_MNT_ROOTFS/var/cache/apt"
	run sudo rm -rf $TARGET_CACHE
	run sudo mkdir -p $TARGET_CACHE
	run sudo mount --bind $Q_CACHE_DIR $Q_MNT_ROOTFS/var/cache/apt
	run sudo mount --bind $Q_MNT_ROOTFS/var/cache/apt $Q_CACHE_DIR 

    ls $TARGET_CACHE
	wait_for_keypress
}


install_overlays() {
	for mnt_target in $Q_MNT_POINTS; do
		num=$(echo $mnt_target | rev | cut -dp -f1 | rev)
		type=$(df -T|sed 's/  */ /g'| grep $mnt_target |cut -d" " -f2)

		RSYNC_OPTS="-Cqr"
		if [[ $type == ext* ]]; then
			RSYNC_OPTS="-CqrXogEpt --numeric-ids"
		fi
		log "Partition $num mounted on $mnt_target, type=$type"
		# Copy overlays
		if [[ -d "$Q_OVERLAYS_DIR/$num" ]]; then
			log "Installing overlay for partition $num"
			run sudo rsync $RSYNC_OPTS "$Q_OVERLAYS_DIR/$num/" "$mnt_target/"
		fi
	done
}


run_scripts() {
	# Run any user scripts from the scripts/ directory
	for script in $(ls $Q_SCRIPTS_DIR); do
		if [[ -x "$Q_SCRIPTS_DIR/$script" ]]; then
			color PURPLE " ==> $script"
			run "$TOOLS_DIR/run-on-image.sh" < "$Q_SCRIPTS_DIR/$script"
			if [[ $? != "0" ]]; then
				log $Q_SCRIPTS_DIR/$script encountered an error. Exiting now
				exit 43
			fi
		else
			log "Script $script is not executable, skipping"
		fi
	done
}

install_packages() {
	log "Installing packages"
# # Install packages specified by $Q_PKG_LIST
# log "Installing packages: $Q_PKG_LIST"
# "$TOOLS_DIR/run-on-image.sh" <<< "apt-get update && apt-get install --no-install-recommends -qy $Q_PKG_LIST"
# log "Done installing packages"
}








wait_for_keypress_before_unmount() {
	wait_for_keypress
}


umount_img() {

	log "Unmounting $Q_DEV_IMG"
	run sync
	
	# TODO test
	cd $Q_MNT_ROOTFS
	run sudo umount proc/
	run sudo umount sys/
	run sudo umount dev/

	# TODO apt cache

	run sudo umount $Q_MNT_ROOTFS/proc
	losd $Q_DEV_IMG
}

finished() {
	log "Building finished, your SD card is now ready at $Q_OUT_IMG"
}

main() {
	step "Setup"
	setup
	load_config $1
	check_vars

	step "Preparing image $Q_OUT_IMG"
	copy_image $Q_IN_IMG $Q_OUT_IMG
	expand_partition
	mount_img
	expand_fs
	mount_live_binds
	mount_apt_cache

	step "Installing overlays..."
	install_overlays

	step "Running scripts... this may take a while"
	run_scripts
	
	# install_packages
	
	wait_for_keypress_before_unmount

	umount_img
	finished
}

main $@