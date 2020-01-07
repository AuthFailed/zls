#!/bin/bash

echo "";
echo "      			 _______       _____  ";
echo "      			|___  / |     / ____|";
echo "      			   / /| |    | (___  ";
echo "      			  / / | |     \___ \ ";
echo "       			 / /__| |____ ____) |";
echo "      			/_____|______|_____/ ";
echo "                                                       ";
echo "         ArchLinux + i3 install script ";
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

# Choose which disk you wanna use
ls /dev | grep "nvme\|sda\|sdb"
yes | sed 2q
read -p "Choose which disk you wanna use: (omit '/dev/')" disk

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
  +100G # 60 gb for root partition
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

# Partition filesystem formatting
if [ $disk = "sda" ] then 
  yes | mkfs.fat -F32 /dev/${disk}1
  yes | mkfs.ext4 /dev/${disk}2
  yes | mkfs.ext4 /dev/${disk}3
  
  mount /dev/${disk}2 /mnt
  mkdir /mnt/boot
  mkdir /mnt/home
  mount /dev/${disk}1 /mnt/boot
  mount /dev/${disk}3 /mnt/home
elif [ $disk = "sdb" ] then
  yes | mkfs.fat -F32 /dev/${disk}1
  yes | mkfs.ext4 /dev/${disk}2
  yes | mkfs.ext4 /dev/${disk}3
  
  mount /dev/${disk}2 /mnt
  mkdir /mnt/boot
  mkdir /mnt/home
  mount /dev/${disk}1 /mnt/boot
  mount /dev/${disk}3 /mnt/home
else 
  yes | mkfs.fat -F32 /dev/${disk}p1
  yes | mkfs.ext4 /dev/${disk}p2
  yes | mkfs.ext4 /dev/${disk}p3
  
  mount /dev/${disk}p2 /mnt
  mkdir /mnt/boot
  mkdir /mnt/home
  mount /dev/${disk}p1 /mnt/boot
  mount /dev/${disk}p3 /mnt/home
fi

# Pacstrap-ping desired disk
pacstrap /mnt base base-devel vim grub networkmanager \
git zsh intel-ucode curl xorg xorg-server go tlp \
xorg-xinit dialog firefox nvidia nvidia-settings wget \
pulseaudio pamixer light feh rofi neofetch xorg-xrandr \
kitty atom libsecret gnome-keyring libgnome-keyring \
os-prober efibootmgr ntfs-3g unzip wireless_tools \
iw wpa_supplicant iwd ppp dhcpcd netctl linux-firmware \
picom xf86-video-intel mesa bumblebee powertop

# Generating fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Updating repo status
arch-chroot /mnt pacman -Syyy

# Setting right timezone
arch-chroot /mnt ln -sf /usr/share/zoneinfo/Europe/Rome /etc/localtime

# Enabling font presets for better font rendering
arch-chroot /mnt ln -s /etc/fonts/conf.avail/70-no-bitmaps.conf /etc/fonts/conf.d
arch-chroot /mnt ln -s /etc/fonts/conf.avail/10-sub-pixel-rgb.conf /etc/fonts/conf.d
arch-chroot /mnt ln -s /etc/fonts/conf.avail/11-lcdfilter-default.conf /etc/fonts/conf.d

# Synchronizing timer
arch-chroot /mnt hwclock --systohc

# Localizing system
arch-chroot /mnt sed -ie 's/#it_IT.UTF-8 UTF-8/it_IT.UTF-8 UTF-8/g' /etc/locale.gen
arch-chroot /mnt sed -ie 's/#it_IT ISO-8859-1/it_IT ISO-8859-1/g' /etc/locale.gen

# Generating locale
arch-chroot /mnt locale-gen

# Setting system language
arch-chroot /mnt echo "LANG=it_IT.UTF-8" >> /mnt/etc/locale.conf

# Choose machine name
arch-chroot /mnt read -p "Choose your machine name (only one word):" machine_name

# Setting machine name
arch-chroot /mnt echo "$machine_name" >> /mnt/etc/hostname

# Setting hosts file
arch-chroot /mnt echo "127.0.0.1 localhost" >> /mnt/etc/hosts
arch-chroot /mnt echo "::1 localhost" >> /mnt/etc/hosts
arch-chroot /mnt echo "127.0.1.1 $machine_name.localdomain $machine_name" >> /mnt/etc/hosts

# Making sudoers do sudo stuff
arch-chroot /mnt sed -ie 's/# %wheel ALL=(ALL)/%wheel ALL=(ALL)/g' /etc/sudoers

# Make initframs
arch-chroot /mnt mkinitcpio -p linux

# Setting root password
echo "Insert password for root:"
arch-chroot /mnt passwd

# Choose your username
arch-chroot /mnt read -p "Insert your username (only one word):" username

# Making user
arch-chroot /mnt useradd -m -G wheel $username

# Setting user password
echo "Insert password for $username:"
arch-chroot /mnt passwd $username

# Installing grub bootloader
arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB --removable

# Making grub auto config
arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg

# Making services start at boot
arch-chroot /mnt systemctl enable tlp.service
arch-chroot /mnt systemctl enable NetworkManager.service
arch-chroot /mnt systemctl enable bumblebeed.service

# Making i3 default for startx
arch-chroot /mnt echo "exec i3" >> /mnt/root/.xinitrc
arch-chroot /mnt echo "exec i3" /mnt/home/$username/.xinitrc

# Installing yay
arch-chroot /mnt sudo -u $username git clone https://aur.archlinux.org/yay.git /home/$username/yay_tmp_install
arch-chroot /mnt sudo -u $username "cd /home/$username/yay_tmp_install && yes | makepkg -si"
arch-chroot /mnt rm -rf /home/$username/yay_tmp_install

# Installing i3-gaps and polybar
arch-chroot /mnt sudo -u $username yay -S i3-gaps --noconfirm
arch-chroot /mnt sudo -u $username yay -S polybar --noconfirm
arch-chroot /mnt sudo -u $username yay -S i3lock-fancy --noconfirm

# Installing fonts
arch-chroot /mnt sudo -u $username mkdir /home/$username/fonts_tmp_folder
arch-chroot /mnt sudo -u $username sudo mkdir /usr/share/fonts/OTF/
# Font Awesome 5 brands
arch-chroot /mnt sudo -u $username "cd /home/$username/fonts_tmp_folder && wget -O fontawesome.zip https://github.com/FortAwesome/Font-Awesome/releases/download/5.9.0/fontawesome-free-5.9.0-desktop.zip && unzip fontawesome.zip"
arch-chroot /mnt sudo -u $username "sudo cp /home/$username/fonts_tmp_folder/fontawesome-free-5.9.0-desktop/otfs/Font\ Awesome\ 5\ Brands-Regular-400.otf /usr/share/fonts/OTF/"
# Material font
arch-chroot /mnt sudo -u $username "cd /home/$username/fonts_tmp_folder && wget https://github.com/adi1090x/polybar-themes/blob/master/polybar-8/fonts/Material.ttf"
arch-chroot /mnt sudo -u $username "sudo cp /home/$username/fonts_tmp_folder/Material.ttf /usr/share/fonts/OTF/"
# Iosevka font
arch-chroot /mnt sudo -u $username "cd /home/$username/fonts_tmp_folder && wget https://github.com/adi1090x/polybar-themes/blob/master/polybar-8/fonts/iosevka-regular.ttf"
arch-chroot /mnt sudo -u $username "sudo cp /home/$username/fonts_tmp_folder/iosevka-regular.ttf /usr/share/fonts/OTF/"
# Meslo for powerline font
arch-chroot /mnt sudo -u $username "cd /home/$username/fonts_tmp_folder && wget https://github.com/powerline/fonts/blob/master/Meslo%20Slashed/Meslo%20LG%20M%20Regular%20for%20Powerline.ttf"
arch-chroot /mnt sudo -u $username "sudo cp /home/$username/fonts_tmp_folder/Meslo\ LG\ M\ Regular\ for\ Powerline.ttf /usr/share/fonts/OTF/"
# Removing fonts tmp folder
arch-chroot /mnt sudo -u $username rm -rf /home/$username/fonts_tmp_folder

# Installing configs
arch-chroot /mnt sudo -u $username mkdir /home/$username/GitHub
arch-chroot /mnt sudo -u $username git clone https://github.com/zetaemme/dotfiles /home/$username/GitHub/dotfiles
arch-chroot /mnt sudo -u $username git clone https://github.com/zetaemme/zls /home/$username/GitHub/zls
arch-chroot /mnt sudo -u $username "chmod 700 /home/$username/GitHub/zls/install_configs.sh"
arch-chroot /mnt sudo -u $username /bin/zsh -c "cd /home/$username/GitHub/zls && ./install_configs.sh"

# Adding device connection instructions to the user home directory
arch-chroot /mnt sudo -u $username "cp /home/$username/GitHub/zls/bluetooth.txt /home/$username/"

# Unmounting all mounted partitions
umount -R /mnt

# Syncing disks
sync

echo ""
echo "INSTALLATION COMPLETE! enjoy :)"
echo ""

sleep 3
