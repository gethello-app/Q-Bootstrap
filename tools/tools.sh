# Thanks to: https://unix.stackexchange.com/a/447977

# Mounts an image and returns the mounted partitions
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

# Unmounts the image
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
