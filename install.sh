#!/bin/bash

echo "";
echo "      			 _______       _____ ";
echo "      			|___  / |     / ____|";
echo "      			   / /| |    | (___  ";
echo "      			  / / | |     \___ \ ";
echo "       			 / /__| |____ ____) |";
echo "      			/_____|______|_____/ ";
echo "                                       ";
echo "         ArchLinux install script ";
echo "";
echo "";

# Syncing system datetime
timedatectl set-ntp true

# Getting latest mirrors for italy and germany
wget -O mirrorlist "https://www.archlinux.org/mirrorlist/?country=DE&country=IT&protocol=https&ip_version=4"
sed -ie 's/^.//g' ./mirrorlist
mv ./mirrorlist /etc/pacman.d/mirrorlist

# Updating mirrors
pacman -Syyy

# Installs FZF
pacman -S --noconfirm fzf

# Choose which type of install you're going to use
install_type=$(printf "Intel\nAMD" | fzf)

# Choose which disk you wanna use
disk=$(sudo fdisk -l | grep 'Disk /dev/' | awk '{print $2,$3,$4}' | sed 's/,$//' | \
fzf --preview 'echo -e "Choose the disk you want to use.\nKeep in mind it will follow this rules:\n\n500M: boot partition\n100G: root partition\nAll remaining space for home partition"' | \
sed -e 's/\/dev\/\(.*\):/\1/' | awk '{print $1}')

# Formatting disk
sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/' << EOF | fdisk /dev/$disk
  g # gpt partitioning
  n # new partition
    # default: primary partition
    # default: partition 1
  +500M # 500 mb on boot partition
    # default: yes if asked
  n # new partition
    # default: primary partition
    # default: partition 2
  +100G # 100 gb for root partition
    # default: yes if asked
  n # new partition
    # default: primary partition
    # default: partition 3
    # default: all space left of for home partition
    # default: yes if asked
  t # change partition type
  1 # selecting partition 1
  1 # selecting EFI partition type
  w # writing changes to disk
EOF

# Outputting partition changes
fdisk -l /dev/$disk

# Partition filesystem formatting and mount
if [ ${disk:0:4} = "nvme" ]; then 
  yes | mkfs.fat -F32 /dev/${disk}p1
  yes | mkfs.ext4 /dev/${disk}p2
  yes | mkfs.ext4 /dev/${disk}p3

  mount /dev/${disk}p2 /mnt
  mkdir /mnt/boot
  mkdir /mnt/home
  mount /dev/${disk}p1 /mnt/boot
  mount /dev/${disk}p3 /mnt/home
else 
  yes | mkfs.fat -F32 /dev/${disk}1
  yes | mkfs.ext4 /dev/${disk}2
  yes | mkfs.ext4 /dev/${disk}3

  mount /dev/${disk}2 /mnt
  mkdir /mnt/boot
  mkdir /mnt/home
  mount /dev/${disk}1 /mnt/boot
  mount /dev/${disk}3 /mnt/home
fi

# установка стандартных пакетов
pacstrap /mnt base base-devel vim grub networkmanager \
git zsh amd-ucode curl xorg xorg-server go tlp termite \
xorg-xinit dialog nvidia nvidia-settings wget bmon \
pulseaudio pamixer light feh rofi neofetch xorg-xrandr \
kitty libsecret gnome-keyring libgnome-keyring dnsutils \
os-prober efibootmgr ntfs-3g unzip wireless_tools ccache \
iw wpa_supplicant iwd ppp dhcpcd netctl linux linux-firmware \
linux-headers picom xf86-video-intel mesa bumblebee powertop \
gtk3 lightdm lightdm-webkit2-greeter lightdm-webkit-theme-litarvan

# Генерация fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Обновление статуса репозиториев
arch-chroot /mnt pacman -Syyy

# Установка таймзоны (+7)
arch-chroot /mnt ln -sf /usr/share/zoneinfo/Asia/Bangkok /etc/localtime

# Подключение пресетов шрифтов для лучшего рендера
arch-chroot /mnt ln -s /etc/fonts/conf.avail/70-no-bitmaps.conf /etc/fonts/conf.d
arch-chroot /mnt ln -s /etc/fonts/conf.avail/10-sub-pixel-rgb.conf /etc/fonts/conf.d
arch-chroot /mnt ln -s /etc/fonts/conf.avail/11-lcdfilter-default.conf /etc/fonts/conf.d

# Синхронизация времени
arch-chroot /mnt hwclock --systohc

# Локализация системы
arch-chroot /mnt sed -ie 's/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/g' /etc/locale.gen
arch-chroot /mnt sed -ie 's/#en_US ISO-8859-1/en_US ISO-8859-1/g' /etc/locale.gen

# Генерация локалей
arch-chroot /mnt locale-gen

# Установка языка системы
arch-chroot /mnt echo "LANG=en_US.UTF-8" >> /mnt/etc/locale.conf

echo ""
echo "INSTALLATION COMPLETE!"
echo ""
