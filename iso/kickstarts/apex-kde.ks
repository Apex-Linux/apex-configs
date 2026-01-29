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
autopart --type=plain --fstype=ext4 --nohome

# === 2. NETWORK & REPOS ===
network --bootproto=dhcp --device=link --activate

# Official Fedora Repos
repo --name=fedora --mirrorlist=https://mirrors.fedoraproject.org/metalink?repo=fedora-43&arch=$basearch
repo --name=updates --mirrorlist=https://mirrors.fedoraproject.org/metalink?repo=updates-released-f43&arch=$basearch

# Apex Linux Core (Your Branding)
repo --name=apex-core --baseurl=https://download.copr.fedorainfracloud.org/results/ackerman/apex-core/fedora-43-$basearch/

# === 3. PACKAGE SELECTION (THE DIET) ===
%packages
# Core Hardware Support
@core
@hardware-support
kernel
kernel-modules
linux-firmware
grub2-efi-x64
shim-x64
efibootmgr

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
anaconda-tools
lorax
livecd-tools

# Essential Tools (No Bloat)
git
wget
nano
htop
neofetch
btop
unzip
tar
xz

# REMOVED BLOAT (Explicitly banned)
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
# Create Live User (No Password)
useradd -m -c "Live System User" liveuser
passwd -d liveuser > /dev/null
usermod -aG wheel liveuser

# Enable SDDM Autologin (Boot straight to desktop)
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
