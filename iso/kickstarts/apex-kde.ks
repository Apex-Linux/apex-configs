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

# FIX 1: Partition Size (8GB Root for Live Image)
part / --size 8192 --fstype ext4

# FIX 2: Root Password (Locked)
rootpw --lock --iscrypted locked

# FIX 3: Services
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
# ANACONDA REMOVED (Replaced by Calamares)

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

# REMOVE OLD INSTALLER
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

# --- 1. DOWNLOAD SYSTEM BRANDING (Terminal) ---
mkdir -p /usr/share/apex-linux
# Download Logo (Passive Asset)
wget https://raw.githubusercontent.com/Apex-Linux/apex-configs/main/iso/branding/logo.txt -O /usr/share/apex-linux/logo.txt

# --- 2. CALAMARES BRANDING (The Transplant) ---
# Create the specific folder Calamares looks for
mkdir -p /usr/share/calamares/branding/apex

# Download the 3 Critical Assets from your Repo
wget https://raw.githubusercontent.com/Apex-Linux/apex-configs/main/iso/branding/calamares/branding.desc -O /usr/share/calamares/branding/apex/branding.desc
wget https://raw.githubusercontent.com/Apex-Linux/apex-configs/main/iso/branding/calamares/squid.png -O /usr/share/calamares/branding/apex/squid.png
wget https://raw.githubusercontent.com/Apex-Linux/apex-configs/main/iso/branding/calamares/welcome.png -O /usr/share/calamares/branding/apex/welcome.png

# FORCE Calamares to use 'apex' branding instead of 'default' or 'fedora'
sed -i 's/branding: default/branding: apex/' /etc/calamares/settings.conf
sed -i 's/branding: fedora/branding: apex/' /etc/calamares/settings.conf

# --- 3. SYSTEM IDENTITY (Change OS Name) ---
sed -i 's/^NAME=.*$/NAME="Apex Linux"/' /etc/os-release
sed -i 's/^PRETTY_NAME=.*$/PRETTY_NAME="Apex Linux 2026.1"/' /etc/os-release

# --- 4. USER & PERMISSIONS SETUP ---
# Create Live User
useradd -m -c "Live System User" liveuser
passwd -d liveuser > /dev/null
usermod -aG wheel liveuser

# FIX: Grant 'wheel' group passwordless sudo (Required for Calamares)
echo "%wheel ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/wheel
chmod 0440 /etc/sudoers.d/wheel

# Enable SDDM Autologin
mkdir -p /etc/sddm.conf.d
cat > /etc/sddm.conf.d/autologin.conf << EOF
[Autologin]
User=liveuser
Session=plasma.desktop
Relogin=false
EOF

# --- 5. CALAMARES LAUNCHER SETUP ---
mkdir -p /home/liveuser/Desktop

# Copy the launcher
cp /usr/share/applications/calamares.desktop /home/liveuser/Desktop/install-apex.desktop

# Fix Permissions so it is trusted and executable
chmod +x /home/liveuser/Desktop/install-apex.desktop
chown -R liveuser:liveuser /home/liveuser/Desktop

# Enable Services
systemctl enable sddm
systemctl enable NetworkManager

# Cleanup
rm -f /var/lib/systemd/random-seed
dnf clean all
%end
