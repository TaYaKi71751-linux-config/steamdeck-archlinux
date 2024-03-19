#!/bin/bash

rfkill unblock all # Enables All devices for Use WLAN
iwctl # Set up WLAN (Manual)
dhcpcd # Run dhcpcd for Set IP Address Automatically by DHCP Client


sudo fdisk /dev/nvme0n1 <<EOF
g
n
p
1

+1024
n
2


w
EOF

sudo parted /dev/nvme0n1 <<EOF
set 1 esp on
EOF


mkfs.vfat /dev/nvme0n1p1

mkfs.ext4 /dev/nvme0n1p2 << EOF
y
EOF

mount /dev/nvme0n1p2 /mnt
mkdir -p /mnt/boot
mount /dev/nvme0n1p1 /mnt/boot

unsquashfs -f -d /mnt $(find / | grep airootfs.sfs | tail -n 1) # extract archiso to /mnt

cp $(find / | grep run | grep vmlinuz | tail -n 1) /mnt/boot/vmlinuz-linux

cp /mnt/etc/mkinitcpio.conf{,.d/archiso.conf} # Use default mkinitcpio

genfstab -pU /mnt > /mnt/etc/fstab

arch-chroot /mnt <<EOF
mkinitcpio -p linux

useradd -mG wheel deck
echo " %wheel ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/wheel

pacman -S plasma kde-{utilities,network} git vim gamescope --noconfirm
pacman -S steam --noconfirm

pacman -Syyu --noconfirm

systemctl enable NetworkManager sddm bluetooth
su deck --command -- cd /home/deck && git clone https://github.com/TaYaKi71751-linux-config/deckifier.git && cd deckifier && bash install.sh
su deck --command -- bash -c "$(curl -LsSf https://raw.githubusercontent.com/TaYaKi71751-linux-config/steam-shortcuts/HEAD/sh/prerun/index.sh)"

bootctl install
echo "title ArchLinux" > /boot/loader/entries/arch.conf
echo "initrd /initramfs-linux.img" >> /boot/loader/entries/arch.conf
echo "linux /vmlinuz-linux" >> /boot/loader/entries/arch.conf
echo "options root=PARTUUID=$(blkid -s PARTUUID -o value /dev/nvme0n1p2) rw" >> /boot/loader/entries/arch.conf
bootctl update

EOF


