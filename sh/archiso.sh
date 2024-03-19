#!/bin/bash

if [ -n "$(echo ${TARGET_INSTALL_DEVICE} | grep dev)" ];then
umount -R /mnt

rfkill unblock all # Enables All devices for Use WLAN
iwctl # Set up WLAN (Manual)
dhcpcd # Run dhcpcd for Set IP Address Automatically by DHCP Client


sudo fdisk ${TARGET_INSTALL_DEVICE} <<EOF
g
n
p
1

+2G
y
n
2


w
EOF

sudo parted ${TARGET_INSTALL_DEVICE} <<EOF
set 1 esp on
EOF

if [ -n "$(echo ${TARGET_INSTALL_DEVICE} | grep nvme)" ];then
	mkfs.vfat ${TARGET_INSTALL_DEVICE}p1
elif [ -n "$(echo ${TARGET_INSTALL_DEVICE} | grep sd)" ];then
	mkfs.vfat ${TARGET_INSTALL_DEVICE}1
fi

if [ -n "$(echo ${TARGET_INSTALL_DEVICE} | grep nvme)" ];then
	mkfs.ext4 -F ${TARGET_INSTALL_DEVICE}p2
elif [ -n "$(echo ${TARGET_INSTALL_DEVICE} | grep sd)" ];then
	mkfs.ext4 -F ${TARGET_INSTALL_DEVICE}2
fi

if [ -n "$(echo ${TARGET_INSTALL_DEVICE} | grep nvme)" ];then
	mount ${TARGET_INSTALL_DEVICE}p2 /mnt
elif [ -n "$(echo ${TARGET_INSTALL_DEVICE} | grep sd)" ];then
	mount ${TARGET_INSTALL_DEVICE}2 /mnt
fi
mkdir -p /mnt/boot
if [ -n "$(echo ${TARGET_INSTALL_DEVICE} | grep nvme)" ];then
	mount ${TARGET_INSTALL_DEVICE}p1 /mnt/boot
elif [ -n "$(echo ${TARGET_INSTALL_DEVICE} | grep sd)" ];then
	mount ${TARGET_INSTALL_DEVICE}1 /mnt/boot
fi

unsquashfs -f -d /mnt $(find / | grep airootfs.sfs | tail -n 1) # extract archiso to /mnt

cp $(find / | grep run | grep vmlinuz | tail -n 1) /mnt/boot/vmlinuz-linux

cp /mnt/etc/mkinitcpio.conf{,.d/archiso.conf} # Use default mkinitcpio

genfstab -pU /mnt > /mnt/etc/fstab

echo "%wheel ALL=(ALL:ALL) NOPASSWD: ALL" > /mnt/etc/sudoers.d/wheel
echo "[multilib]" >> /mnt/etc/pacman.conf
echo "Include = /etc/pacman.d/mirrorlist" >> /mnt/etc/pacman.conf

arch-chroot /mnt <<EOF
mkinitcpio -p linux

useradd -mG wheel deck

pacman-key --init
pacman-key --populate
pacman -Syyu --noconfirm
pacman -S sddm plasma-meta kde-{utilities-meta,network-meta} git vim gamescope  --noconfirm
pacman -S linux-zen linux-zen-headers --noconfirm
pacman -S vulkan-intel lib32-vulkan-intel --noconfirm
pacman -S vulkan-radeon lib32-vulkan-radeon --noconfirm

pacman -S steam --noconfirm


systemctl enable NetworkManager sddm bluetooth
cd /tmp && git clone https://github.com/TaYaKi71751-linux-config/deckifier.git && cd deckifier && USER=deck bash install.sh

bootctl install
bootctl update
mkinitcpio -p linux
mkinitcpio -p linux-zen

EOF

mkdir -p /mnt/home/deck/Desktop
echo '#!/bin/bash' >> /mnt/home/deck/Desktop/steam-shortcuts.sh
echo 'bash -c "$(curl -LsSf https://raw.githubusercontent.com/TaYaKi71751-linux-config/steam-shortcuts/HEAD/sh/prerun/index.sh)"' >> /mnt/home/deck/Desktop/steam-shortcuts.sh
echo '#!/bin/bash' >> /mnt/home/deck/Desktop/deckifier.sh
echo 'cd ${HOME}; git clone https://github.com/TaYaKi71751-linux-config/deckifier.git; cd deckifier; git pull; bash install.sh' >> /mnt/home/deck/Desktop/deckifier.sh

echo "title ArchLinux" > /mnt/boot/loader/entries/arch.conf
echo "initrd /initramfs-linux-zen.img" >> /mnt/boot/loader/entries/arch.conf
echo "linux /vmlinuz-linux-zen" >> /mnt/boot/loader/entries/arch.conf
if [ -n "$(echo ${TARGET_INSTALL_DEVICE} | grep nvme)" ];then
	echo "options root=PARTUUID=$(blkid -s PARTUUID -o value ${TARGET_INSTALL_DEVICE}p2) rw" >> /mnt/boot/loader/entries/arch.conf
elif [ -n "$(echo ${TARGET_INSTALL_DEVICE} | grep sd)" ];then
	echo "options root=PARTUUID=$(blkid -s PARTUUID -o value ${TARGET_INSTALL_DEVICE}2) rw" >> /mnt/boot/loader/entries/arch.conf
fi
else
 echo	\$TARGET_INSTALL_DEVICE was not set. Set like next lines.
	echo export TARGET_INSTALL_DEVICE=/dev/nvmeXnY
	echo export TARGET_INSTALL_DEVICE=/dev/sdX
fi
arch-chroot /mnt <<EOF
chown -R deck:deck /home/deck/
EOF
