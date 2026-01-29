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

# FIX 1: Partition Size
part / --size 8192 --fstype ext4

# FIX 2: Root Password
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

# The Installer
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
%end

# === 4. POST-INSTALL CONFIGURATION ===
%post
# --- 1. SETUP FASTFETCH CUSTOM LOGO ---
mkdir -p /usr/share/apex-linux
cat > /usr/share/apex-linux/logo.txt << 'ASCII_EOF'
      / \
     /   \      APEX LINUX
    /  ^  \     ----------
   /  / \  \    2026.1
  /  /___\  \
 /___________\
ASCII_EOF

mkdir -p /etc/skel/.config/fastfetch
cat > /etc/skel/.config/fastfetch/config.jsonc << 'JSON_EOF'
{
  "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
  "logo": {
    "source": "/usr/share/apex-linux/logo.txt",
    "padding": { "top": 1, "left": 2 }
  },
  "modules": [
    "title", "separator", "os", "host", "kernel", "uptime", "packages", "shell", "de", "wm", "cpu", "memory", "disk", "colors"
  ]
}
JSON_EOF

# --- 2. USER & SYSTEM SETUP ---
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

# --- 3. CALAMARES SETUP (This ensures the installer appears) ---
mkdir -p /home/liveuser/Desktop
# Copy the launcher to the desktop
cp /usr/share/applications/calamares.desktop /home/liveuser/Desktop/install-apex.desktop
# Make it executable so it can run
chmod +x /home/liveuser/Desktop/install-apex.desktop
# Give it to the user
chown -R liveuser:liveuser /home/liveuser/Desktop

# Enable Services
systemctl enable sddm
systemctl enable NetworkManager

# Cleanup
rm -f /var/lib/systemd/random-seed
dnf clean all
%end
