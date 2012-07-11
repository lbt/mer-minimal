# -*-mic2-options-*- -f raw --copy-kernel --record-pkgs=name --pkgmgr=yum --arch=armv7hl -*-mic2-options-*-
# 

lang en_US.UTF-8
keyboard gb
timezone --utc Europe/London
part / --size 3600 --ondisk mmcblk0p --fstype=ext4
# This is not used currently. It is here because the /boot partition
# needs to be the partition number 3 for the u-boot usage.
part swap --size=8 --ondisk mmcblk0p --fstype=swap
# This partition is made so that u-boot can find the kernel
part /boot --size=32 --ondisk mmcblk0p --fstype=vfat

rootpw mer
xconfig --startxonboot

user --name mer  --groups audio,video --password mer

################################################################ Mer Core
repo --name=mer-core --baseurl=http://releases.merproject.org/releases/latest/builds/armv7hl/packages/ --save --debuginfo

################################################################ Hardware adaptation
repo --name=ce-adaptation-n9xx-common --baseurl=http://repo.pub.meego.com/CE:/Adaptation:/N9xx-common/Mer_Core_armv7hl/ --save
repo --name=ce-adaptation-n900 --baseurl=http://repo.pub.meego.com/CE:/Adaptation:/N900/CE_Adaptation_N9xx-common_armv7hl/ --save

################################################################ Mer Tools
# We'll use the Mer Tools repo to get access to some development tools
# repo --name=ce-utils --baseurl=http://repo.pub.meego.com/CE:/Utils/Mer_Core_armv7hl/ --save
repo --name=mer-tools --baseurl=http://repo.pub.meego.com/Mer:/Tools/Mer_Core_armv7hl/ --save


################################################################ Simple UX
repo --name=mer-tools --baseurl=http://repo.pub.meego.com//home:/lbt:/Mer:/UX/Mer_Core_armv7hl/ --save



%packages

@Mer Core
@Mer Graphics Common
@Mer Connectivity
@Mer Minimal Xorg

# N900 HA
@Nokia N900 Support
@Nokia N900 Proprietary Support
kernel-adaptation-n900

# Ueful applications
openssh-clients
openssh-server
#less

#ce-backgrounds
#plymouth-lite
vim-enhanced

# To enable commandline wifi setup
# but see http://git.kernel.org/?p=network/connman/connman.git;a=blob;f=doc/config-format.txt;h=4f768325022e41629cc59d851afbdcfe62a1c4f5;hb=HEAD for connman config
connman-test


# for Qt5 Demos
mer-not-a-ux

%end


# Some of this is hacks until the packages are updated, some is best done in the .ks
%post
# work around for poor key import UI in PackageKit
rm -f /var/lib/rpm/__db*
rpm --rebuilddb

# Prelink can reduce boot time
if [ -x /usr/sbin/prelink ]; then
    /usr/sbin/prelink -aRqm
fi

# Hack to fix the plymouth based splash screen on N900
#mv /usr/bin/ply-image /usr/bin/ply-image-real
#cat > /usr/bin/ply-image << EOF
##!/bin/sh
#echo 32 > /sys/class/graphics/fb0/bits_per_pixel
#exec /usr/bin/ply-image-real $@
#EOF
#chmod +x /usr/bin/ply-image


# Remove cursor from showing during startup BMC#14991
echo "xopts=-nocursor" >> /etc/sysconfig/uxlaunch

# Use eMMC swap partition as MeeGo swap as well.
# Because of the 2nd partition is swap for the partition numbering
# we can just change the current fstab entry to match the eMMC partition.
sed -i 's/mmcblk0p2/mmcblk1p3/g' /etc/fstab

# This causes problems with the bme in N900 images so removing for now.
rm -f /lib/modules/*/kernel/drivers/power/bq27x00_battery.ko
# Remove cursor from showing during startup BMC#14991
echo "xopts=-nocursor" >> /etc/sysconfig/uxlaunch

# Without this line the rpm don't get the architecture right.
echo -n 'armv7hl-meego-linux' > /etc/rpm/platform
 
# Also libzypp has problems in autodetecting the architecture so we force tha as well.
# https://bugs.meego.com/show_bug.cgi?id=11484
echo 'arch = armv7hl' >> /etc/zypp/zypp.conf

# Set up proper target for libmeegotouch
Config_Src=`gconftool-2 --get-default-source`
gconftool-2 --direct --config-source $Config_Src \
  -s -t string /meegotouch/target/name N900
# Wait a bit more than the default 5s when starting application.
mkdir -p /etc/xdg/mcompositor/
echo "close-timeout-ms 15000;" > /etc/xdg/mcompositor/new-mcompositor.conf

################################################################
# Configure Networking

## Enable networking
mkdir /var/lib/connman
cat <<EOF > /var/lib/connman/wlan.config 
[global]
Name = Wifi
Description = Default wifi
Protected = TRUE

[service_wifi]
Type=wifi
Passphrase=<WPA2 passphrase>
Name=<SSID NAME>
Favorite=true
AutoConnect=true
EOF

# Modify Connman settings, skipping sections until wifi, enable it and then emit remaining stuff:
# perl -ei 'while (<>) { print $_;break if /^[wifi]/i; }; while (<>) { s/^Enable=.*/Enable=true/i; print $_;break if /^[/; };while (<>) { print $_ }; ' /var/lib/connman/settings

# Edit not needed, create default values instead
cat <<EOF > /var/lib/connman/settings
[global]
OfflineMode=false

[Bluetooth]
Enable=false

[WiFi]
Enable=true
EOF

%end

%post --nochroot

# Modify the HOSTNAME here (no perl in minimal Mer)
perl -pi -e 's/^HOSTNAME=.*/HOSTNAME=localhost.localdomain/; ' $INSTALL_ROOT/etc/sysconfig/network 

if [ -n "$IMG_NAME" ]; then
    echo "BUILD: $IMG_NAME" >> $INSTALL_ROOT/etc/mer-release
fi

%end
