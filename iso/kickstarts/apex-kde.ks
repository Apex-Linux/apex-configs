# Apex Linux KDE - Minimal Edition (Partition Fixed)
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

# FIX: Define the virtual disk size (8GB) for the build process
part / --size 8192 --fstype ext4

# === 2. NETWORK & INSTALLATION SOURCE ===
network --bootproto=dhcp --device=link --activate

# Installation Source (Core Fedora)
url --mirrorlist=https://mirrors.fedoraproject.org/metalink?repo=fedora-43&arch=$basearch

# Additional Repos
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

# Live System Tools
dracut-live
livesys-scripts
anaconda
anaconda-install-env-deps
anaconda-live

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

# Networking & Audio
NetworkManager
NetworkManager-wifi
plasma-nm
pipewire
pipewire-alsa
pipewire-pulseaudio
wireplumber

# The Installer
calamares

# Essential Tools
git
wget
nano
htop
neofetch
btop
unzip
tar
xz

# REMOVED BLOAT
-libreoffice-*
-thunderbird
-firefox*
-kmail
-kontact
-akregator
-dragon
-elisa
-gwenview
-okular
-kmines
-kmahjongg
-kpat
-dnfdragora
%end

# === 4. POST-INSTALL CONFIGURATION ===
%post
# Create Live User
useradd -m -c "Live System User" liveuser
passwd -d liveuser > /dev/null
usermod -aG wheel liveuser

# Enable SDDM Autologin
mkdir -p /etc/sddm.conf.d
cat > /etc/sddm.conf.d/autologin.conf << EOF
[Autologin]
User=liveuser
Session=plasma.desktop
Relogin=false
EOF

# Put "Install Apex Linux" on the Desktop
mkdir -p /home/liveuser/Desktop
cp /usr/share/applications/calamares.desktop /home/liveuser/Desktop/install-apex.desktop
chmod +x /home/liveuser/Desktop/install-apex.desktop
chown -R liveuser:liveuser /home/liveuser/Desktop

# Enable Services
systemctl enable sddm
systemctl enable NetworkManager

# Cleanup
rm -f /var/lib/systemd/random-seed
dnf clean all
%end
