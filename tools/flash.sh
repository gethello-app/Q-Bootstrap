#!/bin/bash

if [[ -z "$2" ]]; then
	echo "Usage: $0 <image> <drive>"
	exit 1
fi

echo "Flashing $1 onto $2"
echo sudo dd conv=fdatasync bs=16M oflag=sync status=progress if="$1" of="$2"
sudo dd conv=fdatasync bs=16M oflag=sync status=progress if="$1" of="$2"
sync
