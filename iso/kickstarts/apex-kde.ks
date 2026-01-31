# Apex Linux KDE - Minimal Edition 
# Base: Fedora 43
# Version: 2026.1

# === 1. SYSTEM SETTINGS ===
lang en_US.UTF-8
keyboard us
timezone UTC
selinux --enforcing
firewall --enabled --service=mdns
xconfig --startxonboot
zerombr
clearpart --all --initlabel


part / --size 8192 --fstype ext4

rootpw --lock --iscrypted locked

services --enabled=NetworkManager,ModemManager --disabled=sshd

# Shutdown after build
shutdown

# === 2. NETWORK & REPOS ===
network --bootproto=dhcp --device=link --activate

# Installation Source
url --mirrorlist=https://mirrors.fedoraproject.org/metalink?repo=fedora-43&arch=$basearch

# Repositories
repo --name=updates --mirrorlist=https://mirrors.fedoraproject.org/metalink?repo=updates-released-f43&arch=$basearch
repo --name=apex-core --baseurl=https://download.copr.fedorainfracloud.org/results/ackerman/apex-core/fedora-43-$basearch/

# === 3. PACKAGE SELECTION ===
%packages

# Core Hardware
@core
@hardware-support
kernel
kernel-modules
linux-firmware
grub2-efi-x64
shim-x64
efibootmgr
grub2-efi-x64-cdboot
syslinux

# Live System Tools
dracut-live
livesys-scripts

# Security
selinux-policy
selinux-policy-targeted

# Your Identity
apex-release

# The Desktop (Minimal KDE)
plasma-desktop
plasma-workspace
plasma-workspace-wayland
sddm
kwin
konsole
dolphin
ark
spectacle
kate
gwenview
polkit-kde

# Networking & Audio
NetworkManager
NetworkManager-wifi
ModemManager
plasma-nm
pipewire
pipewire-alsa
pipewire-pulseaudio
wireplumber

# The Installer (The ONLY one we need)
calamares

# Essential Tools
git
wget
nano
htop
btop
unzip
tar
xz
fastfetch
ntfs-3g
ntfs-3g-system-compression
exfatprogs
dosfstools
fuse

# REMOVED BLOAT
-libreoffice-*
-thunderbird
-firefox*
-kmail
-kontact
-akregator
-dragon
-elisa
-okular
-kmines
-kmahjongg
-kpat
-dnfdragora

# FIX: REMOVE ANNOYING WELCOME SCREEN
-plasma-welcome
-plasma-welcome-agent

# FIX: REMOVE NETWORK BOOT NOISE (Fixes 'Dracut URL' error)
-dracut-network

# REMOVE OLD INSTALLER (Critical Space Saver ~300MB)
-anaconda*
-anaconda-core
-anaconda-gui
-anaconda-widgets
-anaconda-tui
-gnome-kiosk
-initial-setup
-initial-setup-gui
%end

# === 4. POST-INSTALL CONFIGURATION ===
%post

# --- 1. DOWNLOAD SYSTEM BRANDING ---
mkdir -p /usr/share/apex-linux
wget https://raw.githubusercontent.com/Apex-Linux/apex-configs/main/iso/branding/logo.txt -O /usr/share/apex-linux/logo.txt

# --- 2. CALAMARES BRANDING ---
mkdir -p /usr/share/calamares/branding/apex
wget https://raw.githubusercontent.com/Apex-Linux/apex-configs/main/iso/branding/calamares/branding.desc -O /usr/share/calamares/branding/apex/branding.desc
wget https://raw.githubusercontent.com/Apex-Linux/apex-configs/main/iso/branding/calamares/squid.png -O /usr/share/calamares/branding/apex/squid.png
wget https://raw.githubusercontent.com/Apex-Linux/apex-configs/main/iso/branding/calamares/welcome.png -O /usr/share/calamares/branding/apex/welcome.png

# Force Calamares to use 'apex' branding
sed -i 's/branding: default/branding: apex/' /etc/calamares/settings.conf
sed -i 's/branding: fedora/branding: apex/' /etc/calamares/settings.conf

# --- 3. FIX: UNIVERSAL FETCH BRANDING (Global) ---
cat > /etc/profile.d/apex-branding.sh << 'EOF'

# Force Fastfetch (Modern)
alias fastfetch='fastfetch --logo /usr/share/apex-linux/logo.txt --logo-type file --logo-color-1 blue'

# Force Neofetch (Legacy)
alias neofetch='neofetch --source /usr/share/apex-linux/logo.txt --ascii_distro "Apex Linux"'

# Force Screenfetch (Old School)
alias screenfetch='screenfetch -A "Apex Linux" -D "Apex Linux"'
EOF
chmod +x /etc/profile.d/apex-branding.sh

# --- 4. SYSTEM ICONS---
cp /usr/share/calamares/branding/apex/squid.png /usr/share/pixmaps/fedora-logo-sprite.png
cp /usr/share/calamares/branding/apex/squid.png /usr/share/pixmaps/fedora-logo.png 2>/dev/null || true
cp /usr/share/calamares/branding/apex/squid.png /usr/share/icons/hicolor/48x48/apps/fedora-logo-icon.png 2>/dev/null || true

# --- 5. SYSTEM IDENTITY (The "Root" Source) ---
sed -i 's/^NAME=.*$/NAME="Apex Linux"/' /etc/os-release
sed -i 's/^PRETTY_NAME=.*$/PRETTY_NAME="Apex Linux"/' /etc/os-release
sed -i 's/^ID=.*$/ID=apex/' /etc/os-release

# Update /etc/issue (TTY Login Screen)
echo "Apex Linux \n \l" > /etc/issue

# --- 6. USER & PERMISSIONS ---
useradd -m -c "Live System User" liveuser
passwd -d liveuser > /dev/null
usermod -aG wheel liveuser
echo "%wheel ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/wheel
chmod 0440 /etc/sudoers.d/wheel

# --- 7. DARK MODE---
mkdir -p /home/liveuser/.config
cat > /home/liveuser/.config/kdeglobals << 'EOF'
[General]
ColorScheme=BreezeDark
Name=Breeze Dark

[KDE]
LookAndFeelPackage=org.kde.breezedark.desktop
EOF
chown -R liveuser:liveuser /home/liveuser/.config

# --- 8. AUTOSTART CALAMARES ---
mkdir -p /home/liveuser/.config/autostart
cat > /home/liveuser/.config/autostart/calamares.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=Install Apex Linux
GenericName=Live Installer
Exec=calamares
Icon=/usr/share/calamares/branding/apex/squid.png
Terminal=false
StartupNotify=true
Categories=System;Qt;
EOF

# Also put it on the Desktop
mkdir -p /home/liveuser/Desktop
cp /home/liveuser/.config/autostart/calamares.desktop /home/liveuser/Desktop/install-apex.desktop
chmod +x /home/liveuser/Desktop/install-apex.desktop

# Ownership
chown -R liveuser:liveuser /home/liveuser

# Enable SDDM Autologin
mkdir -p /etc/sddm.conf.d
cat > /etc/sddm.conf.d/autologin.conf << EOF
[Autologin]
User=liveuser
Session=plasma.desktop
Relogin=false
EOF

# Enable Services
systemctl enable sddm
systemctl enable NetworkManager

# Cleanup
rm -f /var/lib/systemd/random-seed
dnf clean all
%end
