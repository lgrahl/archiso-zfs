#!/bin/bash
set -euo pipefail
# This script load zfs kernel module for any archiso.
# github.com/eoli3n (heavily modified by github.com/lgrahl)
# Thanks to CalimeroTeknik on #archlinux-fr, FFY00 on #archlinux-projects, JohnDoe2 on #regex

print () {
    echo -e "\n\033[1m> $1\033[0m"
}

### Main

# Test if archiso is running
if ! grep 'arch.*iso' /proc/cmdline
then
    print "You are not running archiso, exiting."
    exit 1
fi

print "Increase cowspace to half of RAM"
mount -o remount,size=50% /run/archiso/cowspace

# Init archzfs repository
print "Add archzfs repo"
curl -L https://archzfs.com/archzfs.gpg | pacman-key -a -
pacman-key --lsign-key $(curl -L https://raw.githubusercontent.com/openzfs/openzfs-docs/master/docs/Getting%20Started/Arch%20Linux/archzfs-repo/key-id)
curl -L https://raw.githubusercontent.com/openzfs/openzfs-docs/master/docs/Getting%20Started/Arch%20Linux/archzfs-repo/mirrorlist-archzfs > /etc/pacman.d/mirrorlist-archzfs
cat >> /etc/pacman.conf <<"EOF"

[archzfs]
Include = /etc/pacman.d/mirrorlist-archzfs
EOF
pacman -Sy

# Install matching linux-headers for currently running kernel
print "Installing linux-headers for running kernel"
kernel_version=$(uname -r | sed -E 's/^([^-]+)-(.*)$/\1.\2/')
pacman -U --noconfirm https://archive.archlinux.org/packages/l/linux-headers/linux-headers-${kernel_version}-x86_64.pkg.tar.zst

# Install DKMS and ZFS packages
print "Installing dkms zfs-dkms zfs-utils"
pacman -S --noconfirm dkms zfs-dkms zfs-utils

# Load kernel module
modprobe zfs || exit 1
echo -e "\n\e[32mZFS is ready\n"

