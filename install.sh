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
# disk mount
mount /dev/${selected_disk}3 /mnt
mkdir /mnt/boot
mkdir /mnt/home
mount /dev/${selected_disk}1 /mnt/boot
mount /dev/${selected_disk}2 /mnt/home

# Choosing desktop environment
de=$(printf "Deepin\ni3\nGNOME" | fzf)

# Pacstrap-ping
if [ $install_type = "Intel" ]; then
	if [ $de = "i3" ]; then
  		pacstrap /mnt base base-devel vim grub networkmanager \
  		git zsh intel-ucode curl xorg xorg-server go tlp termite \
  		xorg-xinit dialog nvidia nvidia-settings wget bmon \
  		pulseaudio pamixer light feh rofi neofetch xorg-xrandr \
  		kitty libsecret gnome-keyring libgnome-keyring dnsutils \
  		os-prober efibootmgr ntfs-3g unzip wireless_tools ccache \
  		iw wpa_supplicant iwd ppp dhcpcd netctl linux linux-firmware \
  		linux-headers picom xf86-video-intel mesa bumblebee powertop \
  		gtk3 lightdm lightdm-webkit2-greeter lightdm-webkit2-greeter-litarvan
	elif [ $de = "GNOME" ]; then
		pacstrap /mnt base base-devel vim grub networkmanager \
  		git zsh intel-ucode curl xorg xorg-server go tlp ccache \
  		xorg-xinit dialog nvidia nvidia-settings wget \
		pulseaudio neofetch xorg-xrandr kitty os-prober ntfs-3g \
		efibootmgr unzip wireless_tools iw wpa_supplicant iwd ppp dhcpcd netctl \
		linux linux-firmware linux-headers mesa gtk3 gnome gnome-extra gdm
	else
		pacstrap /mnt base base-devel vim grub networkmanager \
  		git zsh intel-ucode curl xorg xorg-server go tlp ccache \
  		xorg-xinit dialog nvidia nvidia-settings wget \
		pulseaudio neofetch xorg-xrandr kitty os-prober ntfs-3g \
		efibootmgr unzip wireless_tools iw wpa_supplicant iwd ppp dhcpcd netctl \
		linux linux-firmware linux-headers mesa gtk3 lightdm deepin deepin-extra
	fi
else
	if [ $de = "i3" ]; then
		pacstrap /mnt base base-devel vim grub networkmanager \
  		git zsh amd-ucode curl xorg xorg-server go tlp termite \
  		xorg-xinit dialog nvidia nvidia-settings wget bmon \
  		pulseaudio pamixer light feh rofi neofetch xorg-xrandr \
  		kitty libsecret gnome-keyring libgnome-keyring dnsutils \
  		os-prober efibootmgr ntfs-3g unzip wireless_tools ccache \
  		iw wpa_supplicant iwd ppp dhcpcd netctl linux linux-firmware \
  		linux-headers picom xf86-video-intel mesa bumblebee powertop \
  		gtk3 lightdm lightdm-webkit2-greeter lightdm-webkit2-greeter-litarvan
	elif [ $de = "GNOME" ]; then
		pacstrap /mnt base base-devel vim grub networkmanager \
  		git zsh amd-ucode curl xorg xorg-server go tlp ccache \
  		xorg-xinit dialog nvidia nvidia-settings wget \
		pulseaudio neofetch xorg-xrandr kitty os-prober ntfs-3g \
		efibootmgr unzip wireless_tools iw wpa_supplicant iwd ppp dhcpcd netctl \
		linux linux-firmware linux-headers mesa gtk3 gnome gnome-extra gdm
	else
		pacstrap /mnt base base-devel vim grub networkmanager \
  		git zsh amd-ucode curl xorg xorg-server go tlp ccache \
  		xorg-xinit dialog nvidia nvidia-settings wget \
		pulseaudio neofetch xorg-xrandr kitty os-prober ntfs-3g \
		efibootmgr unzip wireless_tools iw wpa_supplicant iwd ppp dhcpcd netctl \
		linux linux-firmware linux-headers mesa gtk3 lightdm deepin deepin-extra
	fi
fi

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
arch-chroot /mnt read -p "Choose your machine name (only one word):" machine

# Setting machine name
arch-chroot /mnt echo ${machine} >> /mnt/etc/hostname

# Setting hosts file
arch-chroot /mnt echo "127.0.0.1 localhost" >> /mnt/etc/hosts
arch-chroot /mnt echo "::1 localhost" >> /mnt/etc/hosts
arch-chroot /mnt echo "127.0.1.1 ${machine}.localdomain ${machine}" >> /mnt/etc/hosts

# Making sudoers do sudo stuff
arch-chroot /mnt sed -ie 's/# %wheel ALL=(ALL)/%wheel ALL=(ALL)/g' /etc/sudoers

# Choose your username
arch-chroot /mnt read -p "Insert your username (only one word):" username

# Make initframs
arch-chroot /mnt mkinitcpio -p linux

# Setting root password
echo "Insert password for root:"
arch-chroot /mnt passwd

# Making user
arch-chroot /mnt useradd -m -G wheel ${username}

# Setting user password
echo "Insert password for ${username}:"
arch-chroot /mnt passwd ${username}

# Installing grub bootloader
arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB --removable

# Making grub auto config
arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg

# Making services start at boot
if [ $de = "i3" ]; then
	arch-chroot /mnt systemctl enable tlp.service
	arch-chroot /mnt systemctl enable NetworkManager.service
	arch-chroot /mnt systemctl enable bumblebeed.service
	arch-chroot /mnt systemctl enable lightdm.service
	arch-chroot /mnt systemctl enable firewalld.service
elif [ $de = "Deepin" ]; then
	arch-chroot /mnt systemctl enable tlp.service
	arch-chroot /mnt systemctl enable NetworkManager.service
	arch-chroot /mnt systemctl enable lightdm.service
	arch-chroot /mnt systemctl enable firewalld.service
else
	arch-chroot /mnt systemctl enable tlp.service
	arch-chroot /mnt systemctl enable NetworkManager.service
	arch-chroot /mnt systemctl enable gdm.service
	arch-chroot /mnt systemctl enable firewalld.service
fi

# Making i3 default for startx (only if i3 is DE)
if [ $de = "i3" ]; then
	arch-chroot /mnt echo "exec i3" >> /mnt/root/.xinitrc
	arch-chroot /mnt echo "exec i3" > /mnt/home/${username}/.xinitrc
fi

# Makepkg optimization
arch-chroot /mnt sed -i -e 's/#MAKEFLAGS="-j2"/MAKEFLAGS=-j'$(nproc --ignore 1)'/' -e 's/-march=x86-64 -mtune=generic/-march=native/' -e 's/xz -c -z/xz -c -z -T '$(nproc --ignore 1)'/' /etc/makepkg.conf
arch-chroot /mnt sed -ie 's/!ccache/ccache/g' /etc/makepkg.conf

# Installing yay
arch-chroot /mnt sudo -u $username mkdir /home/${username}/yay_tmp_install
arch-chroot /mnt sudo -u ${username} git clone https://aur.archlinux.org/yay.git /home/${username}/yay_tmp_install
arch-chroot /mnt sudo -u ${username} cd /home/${username}/yay_tmp_install && yes | makepkg -si
arch-chroot /mnt rm -rf /home/${username}/yay_tmp_install

if [ $de = "i3" ]; then
	# Installing i3-gaps and polybar
	arch-chroot /mnt sudo -u ${username} yay -S --noconfirm i3-gaps 
	arch-chroot /mnt sudo -u ${username} yay -S --noconfirm polybar
	arch-chroot /mnt sudo -u ${username} yay -S --noconfirm brave-bin
	arch-chroot /mnt sudo -u ${username} yay -S --noconfirm otf-font-awesome

	# Installing fonts
	arch-chroot /mnt sudo -u ${username} mkdir /home/${username}/fonts_tmp_folder
	arch-chroot /mnt sudo -u ${username} sudo mkdir /usr/share/fonts/OTF/

	# Material font
	arch-chroot /mnt sudo -u ${username} "cd /home/${username}/fonts_tmp_folder && wget https://github.com/adi1090x/polybar-themes/blob/master/polybar-8/fonts/Material.ttf"
	arch-chroot /mnt sudo -u ${username} "sudo cp /home/${username}/fonts_tmp_folder/Material.ttf /usr/share/fonts/OTF/"
	# Iosevka font
	arch-chroot /mnt sudo -u ${username} "cd /home/${username}/fonts_tmp_folder && wget https://github.com/adi1090x/polybar-themes/blob/master/polybar-8/fonts/iosevka-regular.ttf"
	arch-chroot /mnt sudo -u ${username} "sudo cp /home/${username}/fonts_tmp_folder/iosevka-regular.ttf /usr/share/fonts/OTF/"
	# Meslo for powerline font
	arch-chroot /mnt sudo -u ${username} "cd /home/${username}/fonts_tmp_folder && wget https://github.com/powerline/fonts/blob/master/Meslo%20Slashed/Meslo%20LG%20M%20Regular%20for%20Powerline.ttf"
	arch-chroot /mnt sudo -u ${username} "sudo cp /home/${username}/fonts_tmp_folder/Meslo\ LG\ M\ Regular\ for\ Powerline.ttf /usr/share/fonts/OTF/"
	# Removing fonts tmp folder
	arch-chroot /mnt sudo -u ${username} rm -rf /home/${username}/fonts_tmp_folder

	# Installing configs
	arch-chroot /mnt sudo -u ${username} mkdir /home/${username}/GitHub
	arch-chroot /mnt sudo -u ${username} git clone https://github.com/zetaemme/dotfiles /home/${username}/GitHub/dotfiles
	arch-chroot /mnt sudo -u ${username} git clone https://github.com/zetaemme/zls /home/${username}/GitHub/zls
	arch-chroot /mnt sudo -u ${username} "chmod +x /home/${username}/GitHub/zls/install_configs.sh"
	arch-chroot /mnt sudo -u ${username} /bin/zsh -c "cd /home/${username}/GitHub/zls && ./install_configs.sh"

	# Setting lightdm greeter
	arch-chroot /mnt sudo -u ${username} sed -i '102s/^#.*greeter-session=/s/^#//' /etc/lightdm/lightdm.conf
	arch-chroot /mnt sudo -u ${username} sed -i '102s/^greeter-session=/ s/$/lightdm-webkit2-greeter/' /etc/lightdm/lightdm.conf

	arch-chroot /mnt sudo -u ${username} sed -i '111s/^#.*session-startup-script=/s/^#//' /etc/lightdm/lightdm.conf
	arch-chroot /mnt sudo -u ${username} sed -i '111s/^session-startup-script=/ s/$//home/zetaemme/.fehbg' /etc/lightdm/lightdm.conf

	arch-chroot /mnt sudo -u ${username} sed -i '21s/^webkit_theme/ s/$/ litarvan' /etc/lightdm/lightdm-webkit2-greeter.conf
else
	arch-chroot /mnt sudo -u ${username} yay -S --noconfirm brave-bin
	
	if [ $de = "Deepin" ]; then
		arch-chroot /mnt sudo -u ${username} sed -i '102s/^#.*greeter-session=/s/^#//' /etc/lightdm/lightdm.conf
		arch-chroot /mnt sudo -u ${username} sed -i '102s/^greeter-session=/ s/$/lightdm-deepin-greeter/' /etc/lightdm/lightdm.conf
	fi
fi

# Unmounting all mounted partitions
umount -R /mnt

# Syncing disks
sync

echo ""
echo "INSTALLATION COMPLETE!"
echo ""

# Waits 3 secs then reboot
sleep 3 && reboot
