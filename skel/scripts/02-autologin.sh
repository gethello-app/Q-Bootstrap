#!/bin/bash

# Automatically login to the graphical user interface as the pi user
# This is in combination with the overlays/2/etc/systemd/system/getty@tty1.service.d/autologin.conf

ln -fs /lib/systemd/system/getty@.service /etc/systemd/system/getty.target.wants/getty@tty1.service
rm -f /etc/systemd/default.target
ln -s /lib/systemd/system/graphical.target /etc/systemd/default.target


