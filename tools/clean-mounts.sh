#!/bin/bash

NAME=$1
if [[ -z "$NAME" ]]; then
    NAME="loop"
fi

for f in /mnt/$NAME*p2; do
    echo sudo umount "$f/proc"
    sudo umount "$f/proc"
    echo sudo umount "$f/sys"
    sudo umount "$f/sys"
    echo sudo umount "$f/dev"
    sudo umount "$f/dev"
done
for f in /mnt/$NAME*p1; do
    echo sudo umount $f
    sudo umount $f
done
