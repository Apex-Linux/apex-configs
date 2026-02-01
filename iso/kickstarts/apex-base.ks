# === APEX LINUX BASE (2026 Modern Edition) ===
lang en_US.UTF-8
keyboard us
timezone UTC
selinux --enforcing
firewall --enabled --service=mdns
xconfig --startxonboot
zerombr
clearpart --all --initlabel

# === 2026 STORAGE LAYOUT (BTRFS) ===
# This enables snapshots, compression, and proper Fedora standards.
reqpart
part /boot/efi --size 512 --fstype efi
part /boot     --size 1024 --fstype ext4
part btrfs.01  --size 8192 --grow --fstype btrfs
btrfs none --label=fedora btrfs.01
btrfs /     --subvol --name=root  label=fedora
btrfs /home --subvol --name=home  label=fedora

rootpw --lock --iscrypted locked

# FIX: Disable Media Check (Fixes "Check Failed" loops)
bootloader --append="rd.live.check=0 rhgb quiet"

# NETWORK
network --bootproto=dhcp --device=link --activate
url --mirrorlist=https://mirrors.fedoraproject.org/metalink?repo=fedora-43&arch=$basearch
repo --name=updates --mirrorlist=https://mirrors.fedoraproject.org/metalink?repo=updates-released-f43&arch=$basearch
# Add your COPR here if you have one later
# repo --name=apex-core --baseurl=...

%packages
@core
@hardware-support
kernel
kernel-modules
kernel-modules-extra
linux-firmware
grub2-efi-x64
shim-x64
efibootmgr
grub2-efi-x64-cdboot
syslinux

# FONTS
@fonts
google-noto-sans-fonts
google-noto-serif-fonts
google-noto-emoji-fonts

# LIVE TOOLS (CRITICAL UPDATES)
dracut-live
dracut-network
dracut-config-generic  # Essential for broad hardware support
livesys-scripts
plymouth
plymouth-system-theme

# MODERN UTILITIES
git
wget
curl
nano
htop
fastfetch
ntfs-3g
btrfs-progs
dosfstools
fuse

# REMOVE ANACONDA (We use Calamares)
-anaconda*
-initial-setup*
%end

%post
# 1. IDENTITY
sed -i 's/^NAME=.*$/NAME="Apex Linux"/' /etc/os-release
sed -i 's/^PRETTY_NAME=.*$/PRETTY_NAME="Apex Linux"/' /etc/os-release
sed -i 's/^ID=.*$/ID=apex/' /etc/os-release
echo -e "Apex Linux \n \l" > /etc/issue

# 2. CRITICAL FIX: DRACUT NETWORK CRASH
# The "get_url_handler" error happens because livenet is missing dependencies in F43.
echo 'add_dracutmodules+=" network livenet "' > /etc/dracut.conf.d/apex-live.conf

# 3. SERVICES
systemctl enable ModemManager || true
systemctl mask speech-dispatcherd || true

# 4. USER
useradd -m -c "Live System User" liveuser
passwd -d liveuser > /dev/null
usermod -aG wheel liveuser
echo "%wheel ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/wheel
chmod 0440 /etc/sudoers.d/wheel
%end
