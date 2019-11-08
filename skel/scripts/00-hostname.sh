#!/bin/bash

# This script changes the hostname if Q_HOSTNAME is set
# We cannot use the hostname command, because it is a syscall (executed on the host machine)

if [[ -z "$Q_HOSTNAME" ]]; then
	echo "No Q_HOSTNAME set"
	exit 0
fi

echo "Setting hostname to $Q_HOSTNAME"
sed -i "s/raspberrypi/$Q_HOSTNAME/g" /etc/hostname
sed -i "s/raspberrypi/$Q_HOSTNAME/g" /etc/hosts
