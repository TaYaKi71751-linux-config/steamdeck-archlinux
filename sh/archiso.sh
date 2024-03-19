#!/bin/bash

rfkill unblock all # Enables All devices for Use WLAN
iwctl # Set up WLAN (Manual)
dhcpcd # Run dhcpcd for Set IP Address Automatically by DHCP Client
(
echo g
# Create a new empty GPT partition table
echo n
# Add a new partition
echo p
# Primary partition
echo 1
# Partition number
echo ""
# First sector (Accept default: 1)
echo 1024 # Last sector (Accept : 1G)

echo n
# Add a new partition
echo 2
# Partition number
echo ""
# First sector (Accept default: 1)
echo ""
# Last sector (Accept default: varies)
echo w
# Write changes
) | sudo fdisk /dev/nvme0n1

(
echo set 1 esp on # Set partition 1 as ESP (EFI)
) | sudo parted /dev/nvme0n1


mkfs.vfat /dev/nvme0n1p1

(
echo y
) | mkfs.ext4 /dev/nvme0n1p2

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
vim /etc/sudoers

pacman -S plasma kde-{utilities,network} git vim gamescope --noconfirm
pacman -S steam --noconfirm

pacman -Syyu --noconfirm

systemctl enable NetworkManager sddm bluetooth
su deck --command -- cd /home/deck && git clone https://github.com/TaYaKi71751-linux-config/deckifier.git && cd deckifier && bash install.sh
su deck --command -- bash -c "$(curl -LsSf https://raw.githubusercontent.com/TaYaKi71751-linux-config/steam-shortcuts/main/sh/prerun/index.sh)"

bootctl install
echo "title ArchLinux" > /boot/loader/entries/arch.conf
echo "initrd /initramfs-linux.img" >> /boot/loader/entries/arch.conf
echo "linux /vmlinuz-linux" >> /boot/loader/entries/arch.conf
echo "options root=PARTUUID=$(blkid -s PARTUUID -o value /dev/nvme0n1p2) rw" >> /boot/loader/entries/arch.conf
bootctl update

exit
EOF


