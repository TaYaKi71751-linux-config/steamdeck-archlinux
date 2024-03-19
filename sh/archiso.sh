#!/bin/bash

umount -R /mnt

rfkill unblock all # Enables All devices for Use WLAN
iwctl # Set up WLAN (Manual)
dhcpcd # Run dhcpcd for Set IP Address Automatically by DHCP Client


sudo fdisk /dev/nvme0n1 <<EOF
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

sudo parted /dev/nvme0n1 <<EOF
set 1 esp on
EOF


mkfs.vfat /dev/nvme0n1p1

mkfs.ext4 -F /dev/nvme0n1p2

mount /dev/nvme0n1p2 /mnt
mkdir -p /mnt/boot
mount /dev/nvme0n1p1 /mnt/boot

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
pacman -S plasma kde-{utilities,network} git vim gamescope --noconfirm
pacman -S vulkan-intel lib32-vulkan-intel --noconfirm
pacman -S vulkan-radeon lib32-vulkan-radeon --noconfirm

pacman -S steam --noconfirm


systemctl enable NetworkManager sddm bluetooth
su deck --command -- && cd /home/deck && git clone https://github.com/TaYaKi71751-linux-config/deckifier.git && cd deckifier && USER=deck bash install.sh
su deck --command -- curl -LsSf https://raw.githubusercontent.com/TaYaKi71751-linux-config/steam-shortcuts/HEAD/sh/prerun/index.sh | bash

bootctl install
bootctl update

EOF

echo "title ArchLinux" > /mnt/boot/loader/entries/arch.conf
echo "initrd /initramfs-linux.img" >> /mnt/boot/loader/entries/arch.conf
echo "linux /vmlinuz-linux" >> /mnt/boot/loader/entries/arch.conf
echo "options root=PARTUUID=$(blkid -s PARTUUID -o value /dev/nvme0n1p2) rw" >> /mnt/boot/loader/entries/arch.conf

