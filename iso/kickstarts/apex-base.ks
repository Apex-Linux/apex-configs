# === APEX LINUX BASE ===
# Shared by KDE, GNOME, and Minimal Editions

# 1. SYSTEM SETTINGS
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
shutdown

# DISABLE MEDIA CHECK (Prevents "CheckISOMD5" boot failure)
bootloader --location=none --append="rd.live.check=0"

# 2. NETWORK & REPOS
network --bootproto=dhcp --device=link --activate
url --mirrorlist=https://mirrors.fedoraproject.org/metalink?repo=fedora-43&arch=$basearch
repo --name=updates --mirrorlist=https://mirrors.fedoraproject.org/metalink?repo=updates-released-f43&arch=$basearch
repo --name=apex-core --baseurl=https://download.copr.fedorainfracloud.org/results/ackerman/apex-core/fedora-43-$basearch/

# 3. BASE PACKAGES
%packages
# Kernel & Hardware
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

# GLOBAL FONTS (Full Support for Bengali, Arabic, CJK, etc.)
@fonts
google-noto-sans-fonts
google-noto-serif-fonts
google-noto-emoji-fonts
google-noto-sans-bengali-fonts
google-noto-sans-arabic-fonts
google-noto-sans-cjk-fonts
google-noto-sans-devanagari-fonts

# Live Tools
dracut-live
livesys-scripts

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

# REMOVE ANACONDA (We use Calamares)
-anaconda*
-anaconda-core
-anaconda-gui
-anaconda-widgets
-anaconda-tui
-gnome-kiosk
-initial-setup
-initial-setup-gui
%end

%post
# 1. SYSTEM IDENTITY
sed -i 's/^NAME=.*$/NAME="Apex Linux"/' /etc/os-release
sed -i 's/^PRETTY_NAME=.*$/PRETTY_NAME="Apex Linux"/' /etc/os-release
sed -i 's/^ID=.*$/ID=apex/' /etc/os-release
echo -e "Apex Linux \n \l" > /etc/issue

# 2. USER SETUP
useradd -m -c "Live System User" liveuser
passwd -d liveuser > /dev/null
usermod -aG wheel liveuser
echo "%wheel ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/wheel
chmod 0440 /etc/sudoers.d/wheel
%end
