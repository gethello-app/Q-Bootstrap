#!/bin/bash


target=$Q_MNT_ROOTFS

# Copy the qemu binary to the target platform
sudo mkdir -p "$target/usr/bin"
sudo cp "/usr/bin/qemu-arm-static" "$target/usr/bin/"
# Execute the command, but dont show annoying warnings
sudo -E chroot "$target" /usr/bin/qemu-arm-static /bin/bash <&0 2>&1 | grep -v "cannot open shared object file"
# Let's do some cleanup
sudo rm "$target/usr/bin/qemu-arm-static"
