#!/bin/bash
set -euo pipefail
# This script load zfs kernel module for any archiso.
# github.com/eoli3n (heavily modified by github.com/lgrahl)
# Thanks to CalimeroTeknik on #archlinux-fr, FFY00 on #archlinux-projects, JohnDoe2 on #regex

print () {
    echo -e "\n\033[1m> $1\033[0m"
}

search_package () {
# $1 is package name to search
# $2 is version to match

    # Set regex to match package
    local regex='href="\K(?![^"]*\.sig)'"$1"'-(?=\d)[^"]*'"$2"'[^"]*x86_64[^"]*'
    # href="               # match href="
    # \K                   # don't return anything matched prior to this point
    # (?![^"]*\.sig)       # remove .sig matches
    # '"$1"'-(?=\d)        # find me '$package-' escaped by shell and ensure that after "-" is a digit
    # [^"]*                # match anything between '"'
    # '"$2"'               # match version escaped by shell
    # [^"]*                # match anything between '"'
    # x86_64               # now match architecture
    # [^"]*                # match anything between '"'
    
    # Set archzfs URLs list
    local urls="http://archzfs.com/archzfs/x86_64/ http://archzfs.com/archive_archzfs/"
    
    # Loop search
    for url in $urls
    do
    
        print "Searching $1 on $url..."
    
        # Query url and try to match package
        local package=$(curl -s "$url" | grep -Po "$regex" | tail -n 1)
    
        # If a package is found
        if [[ -n $package ]]
        then
    
            print "Package \"$package\" found"
    
            # Build package url
            package_url="$url$package"
            return 0
        fi
    done

    # If no package found
    return 1
}

download_package () {
# $1 is package url to download in tmp

    # Set out file
    local filename="${1##*/}"
    package_file="/tmp/$filename"
    print "Download to $package_file ..."

    # Download package in tmp
    cd /tmp
    curl -sO "$1" || return 1
    cd -

    return 0
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

# Search kernel package
# https://github.com/archzfs/archzfs/issues/337#issuecomment-624312576
kernel_version=$(uname -r)

# Search zfs-linux package matching running kernel version
search_package "zfs-linux" "${kernel_version//-/\.}" || exit 1
zfs_linux_url="$package_url"

# Download package
download_package "$zfs_linux_url" || exit 1
zfs_linux_package="$package_file"

# Extract zfs-utils version from zfs-linux PKGINFO
print "Extracting zfs-utils version from zfs-linux PKGINFO"
zfs_utils_version=$(bsdtar -qxO -f "$zfs_linux_package" .PKGINFO | grep -Po 'depend = zfs-utils=\K.*')

# Search zfs-utils package matching zfs-linux package dependency
search_package "zfs-utils" "$zfs_utils_version" || exit 1
zfs_utils_url="$package_url"

# Install packages
print "Installing zfs-utils and zfs-linux"
pacman -Sy
pacman -U "$zfs_utils_url" "$zfs_linux_package" --noconfirm

# Load kernel module
modprobe zfs || exit 1
echo -e "\n\e[32mZFS is ready\n"

