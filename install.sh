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

mount -o remount,size=15G /run/archiso/cowspace
# Syncing system datetime
timedatectl set-ntp true

# Getting latest mirrors for italy and germany
wget -O mirrorlist "https://www.archlinux.org/mirrorlist/?country=RU&protocol=https&ip_version=4"
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
pacstrap /mnt base base-devel vim grub networkmanager firewalld \
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

# Setting machine name
arch-chroot /mnt echo "RomanPC" >> /mnt/etc/hostname

# Setting hosts file
arch-chroot /mnt echo "127.0.0.1 localhost" >> /mnt/etc/hosts
arch-chroot /mnt echo "::1 localhost" >> /mnt/etc/hosts
arch-chroot /mnt echo "127.0.1.1 ${machine}.localdomain ${machine}" >> /mnt/etc/hosts

# Making sudoers do sudo stuff
arch-chroot /mnt sed -ie 's/# %wheel ALL=(ALL)/%wheel ALL=(ALL)/g' /etc/sudoers

# Make initframs
arch-chroot /mnt mkinitcpio -p linux

# Making user
arch-chroot /mnt useradd -m -G wheel authfailed

# Setting user password
arch-chroot /mnt passwd authfailed

# Installing grub bootloader
arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB --removable

# Making grub auto config
arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg

# Making services start at boot
arch-chroot /mnt systemctl enable tlp.service
arch-chroot /mnt systemctl enable NetworkManager.service
arch-chroot /mnt systemctl enable bumblebeed.service
arch-chroot /mnt systemctl enable lightdm.service
arch-chroot /mnt systemctl enable firewalld.service

# Making i3 default for startx
arch-chroot /mnt echo "exec i3" >> /mnt/root/.xinitrc
arch-chroot /mnt echo "exec i3" > /mnt/home/authfailed/.xinitrc

# Makepkg optimization
arch-chroot /mnt sed -i -e 's/#MAKEFLAGS="-j2"/MAKEFLAGS=-j'$(nproc --ignore 1)'/' -e 's/-march=x86-64 -mtune=generic/-march=native/' -e 's/xz -c -z/xz -c -z -T '$(nproc --ignore 1)'/' /etc/makepkg.conf
arch-chroot /mnt sed -ie 's/!ccache/ccache/g' /etc/makepkg.conf

# Installing yay
arch-chroot /mnt su authfailed
mkdir /home/authfailed/yay_tmp_install
git clone https://aur.archlinux.org/yay.git /home/authfailed/yay_tmp_install
cd /home/authfailed/yay_tmp_install && yes | makepkg -si
rm -rf /home/authfailed/yay_tmp_install


# Installing i3-gaps and polybar
yay -S --noconfirm i3-gaps 
yay -S --noconfirm polybar
yay -S --noconfirm brave-bin
yay -S --noconfirm otf-font-awesome

# Installing fonts
mkdir /home/authfailed/fonts_tmp_folder
mkdir /usr/share/fonts/OTF/

# Material font
cd /home/authfailed/fonts_tmp_folder && wget https://github.com/adi1090x/polybar-themes/blob/master/polybar-8/fonts/Material.ttf
sudo cp /home/authfailed/fonts_tmp_folder/Material.ttf /usr/share/fonts/OTF/
# Iosevka font
cd /home/authfailed/fonts_tmp_folder && wget https://github.com/adi1090x/polybar-themes/blob/master/polybar-8/fonts/iosevka-regular.ttf
sudo cp /home/authfailed/fonts_tmp_folder/iosevka-regular.ttf /usr/share/fonts/OTF/
# Meslo for powerline font
cd /home/authfailed/fonts_tmp_folder && wget https://github.com/powerline/fonts/blob/master/Meslo%20Slashed/Meslo%20LG%20M%20Regular%20for%20Powerline.ttf
sudo cp /home/authfailed/fonts_tmp_folder/Meslo\ LG\ M\ Regular\ for\ Powerline.ttf /usr/share/fonts/OTF/
# Removing fonts tmp folder
cd ..
rm -rf /home/authfailed/fonts_tmp_folder

# Installing configs
mkdir /home/authfailed/GitHub
git clone https://github.com/zetaemme/dotfiles /home/authfailed/GitHub/dotfiles
git clone https://github.com/authfailed/zls /home/authfailed/GitHub/zls
chmod +x /home/authfailed/GitHub/zls/install_configs.sh
cd /home/authfailed/GitHub/zls && sudo ./install_configs.sh

# Setting lightdm greeter
sed -i '102s^#.*greeter-session=s^#' /etc/lightdm/lightdm.conf
sed -i '102s^greeter-session= s$lightdm-webkit2-greeter' /etc/lightdm/lightdm.conf

sed -i '111s^#.*session-startup-script=s^#' /etc/lightdm/lightdm.conf
sed -i '111s^session-startup-script= s/$//home/authfailed/.fehbg' /etc/lightdm/lightdm.conf

sed -i '21s^webkit_theme s$ litarvan' /etc/lightdm/lightdm-webkit2-greeter.conf

# Unmounting all mounted partitions
exit
umount -R /mnt

# Syncing disks
sync

echo ""
echo "INSTALLATION COMPLETE!"
echo ""

# Waits 3 secs then reboot
sleep 3 && reboot
