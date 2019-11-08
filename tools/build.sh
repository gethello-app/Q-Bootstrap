#!/bin/bash


TOOLS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"


set -e

if [[ -f "$1" ]]; then
	echo "Sourcing config file $1"
	source $1
	echo "Changing directory to config file location $(dirname $1)"
	cd $(dirname $1)
fi


# Check that all required variables are set in the config file
for var in $(echo "Q_OVERLAYS_DIR Q_BUILD_DIR Q_IMG_DIR Q_SCRIPTS_DIR Q_IN_IMG Q_OUT_IMG"); do
	if [[ ! -v $var ]]; then
		echo "Missing environment variable $var"
		exit 1
	fi
done

echo "Copying $Q_IN_IMG to $Q_OUT_IMG"
cp $Q_IN_IMG $Q_OUT_IMG

if [[ -n $Q_EXPAND_FS_SIZE_MB ]]; then
	# Check that there is an ext* partition
	if ! sudo parted $Q_OUT_IMG <<< p 2>&1 | grep ext; then
		echo "Could not find an ext2/3/4 partition on image"
		exit 1
	fi
	PART_NUM=$(sudo parted $Q_OUT_IMG <<< p 2>&1 | grep ext|head -n1|sed 's/^ *//' |cut -d" " -f1)
	echo "Found ext partition at position $PART_NUM"
	# Expand the image first
	echo "Expanding image file by $Q_EXPAND_FS_SIZE_MB MB"
        dd bs=8M if=/dev/zero of=$Q_OUT_IMG count=$(($Q_EXPAND_FS_SIZE_MB/8)) status=progress oflag=sync,append conv=notrunc
	# Now grow the partition
	echo "Growing the partition"
	sudo growpart $Q_OUT_IMG $PART_NUM
	# We will resize the fs once it is mounted later on
	echo "FS will be expanded after mounting"
fi


# Thanks to: https://unix.stackexchange.com/a/447977
los() (
  img="$1"
  export dev="$(sudo losetup --show -f -P "$img")"
  echo "$dev"
  for part in "$dev"?*; do
    if [ "$part" = "${dev}p*" ]; then
      part="${dev}"
    fi
    dst="/mnt/$(basename "$part")"
    echo "$dst"
    sudo mkdir -p "$dst"
    sudo mount "$part" "$dst"
  done
)

losd() (
  dev="$1"
  for part in "$dev"?*; do
    if [ "$part" = "${dev}p*" ]; then
      part="${dev}"
    fi
    dst="/mnt/$(basename "$part")"
    sudo umount -f "$dst"
  done
  sudo losetup -d "$dev"
)

OUTPUT=$(los $Q_OUT_IMG)
export Q_MNT_POINTS=$(echo $OUTPUT | cut -d" " -f2-)
export Q_DEV_IMG=$(echo $OUTPUT | cut -d" " -f1)

echo "Mounted $IMG on $Q_DEV_IMG"

export Q_MNT_ROOTFS="/mnt/$(basename $Q_DEV_IMG)"p${PART_NUM}
export Q_DEV_ROOTFS="/dev/$(basename $Q_DEV_IMG)"p${PART_NUM}
echo Q_MNT_ROOTFS: $Q_MNT_ROOTFS

if [[ -z "$Q_EXPAND_FS_SIZE" ]]; then
	# Step 2 of expanding the fs
	echo
	echo "======== SIZE BEFORE EXPAND FS =============="
	df -h |grep -E "$Q_DEV_ROOTFS | Avail"
	echo "============================================="
	echo
	echo "Expanding filesystem on partition $PART_NUM to fill remaining space"
	sudo resize2fs $Q_DEV_ROOTFS
	echo
	echo "======== SIZE AFTER EXPAND FS ==============="
	df -h |grep -E "$Q_DEV_ROOTFS | Avail"
	echo "============================================="
	echo
fi


for mnt_target in $Q_MNT_POINTS; do
	num=$(echo $mnt_target | rev | cut -dp -f1 | rev)
	type=$(df -T|sed 's/  */ /g'| grep $mnt_target |cut -d" " -f2)

	RSYNC_OPTS="-Cqr"
	if [[ $type == ext* ]]; then
		RSYNC_OPTS="-CqrXogEpt --numeric-ids"
	fi
	echo "Partition $num mounted on $mnt_target, type=$type"
	# Copy overlays
	if [[ -d "$Q_OVERLAYS_DIR/$num" ]]; then
		echo "Installing overlay for partition $num"
		sudo rsync $RSYNC_OPTS "$Q_OVERLAYS_DIR/$num/" "$mnt_target/"
	fi

done



# We have to expose proc, dev etc
sudo mount --bind /proc $Q_MNT_ROOTFS/proc


# Run any user scripts from the scripts/ directory
for script in $(ls $Q_SCRIPTS_DIR); do
	echo "Executing script $script"
	if [[ -x "$Q_SCRIPTS_DIR/$script" ]]; then
		"$TOOLS_DIR/run-on-image.sh" < "$Q_SCRIPTS_DIR/$script" || exit 43
	else
		echo "Script $script is not executable, skipping"
	fi
done



# Install packages specified by $Q_PKG_LIST
echo "Installing packages: $Q_PKG_LIST"
"$TOOLS_DIR/run-on-image.sh" <<< "apt-get update && apt-get install --no-install-recommends -qy $Q_PKG_LIST"
echo "Done installing packages"






if [[ $Q_KEEP_MOUNTED == "true" ]]; then
	echo "Warning: Q_KEEP_MOUNTED enabled. Verify your partitions at $Q_DEV_IMG and press enter"
	read
fi

echo "Unmounting $Q_DEV_IMG"
sync
sudo umount $Q_MNT_ROOTFS/proc
losd $Q_DEV_IMG


echo "Building finished, your SD card is now ready at $Q_OUT_IMG"
