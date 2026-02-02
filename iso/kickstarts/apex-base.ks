# === APEX LINUX BASE SYSTEM ===
# Version: 2026.1
# Description: Core system definition and repository setup.

lang en_US.UTF-8
keyboard us
timezone UTC
selinux --enforcing
firewall --enabled --service=mdns
xconfig --startxonboot
zerombr
clearpart --all --initlabel

# === LIVE ISO STORAGE ===
part / --size 8192 --fstype ext4
rootpw --lock --iscrypted locked
bootloader --append="rd.live.check=0 rhgb quiet"

# === REPOSITORIES ===
network --bootproto=dhcp --device=link --activate
url --mirrorlist=https://mirrors.fedoraproject.org/metalink?repo=fedora-43&arch=$basearch
repo --name=updates --mirrorlist=https://mirrors.fedoraproject.org/metalink?repo=updates-released-f43&arch=$basearch

# 1. APEX CORE
repo --name=apex-core --baseurl=https://download.copr.fedorainfracloud.org/results/ackerman/apex-core/fedora-$releasever-$basearch/ --cost=50

# 2. TERRA REPO 
repo --name=terra --baseurl=https://repos.fyralabs.com/terra$releasever --cost=60 --noverifyssl

%packages
# === CORE GROUPS ===
@core
@hardware-support
@fonts

# === KERNEL & BOOT ===
kernel
kernel-modules
kernel-modules-extra
linux-firmware
grub2-efi-x64
shim-x64
efibootmgr
grub2-efi-x64-cdboot
syslinux

# === APEX IDENTITY & REPOS ===
# We install our custom release package.
# Note: We EXCLUDE fedora-release at the bottom to prevent conflicts.
apex-release

# Install Terra keys and repo definitions permanently
terra-release 
distribution-gpg-keys

# === LIVE TOOLS ===
dracut-live
dracut-network
dracut-config-generic
livesys-scripts
plymouth
plymouth-system-theme

# === FILESYSTEM SUPPORT ===
kde-partitionmanager
btrfs-progs
xfsprogs
e2fsprogs
dosfstools
ntfs-3g
fuse
f2fs-tools
gparted

# === COMPILATION TOOLS (Temporary) ===
gcc
make
gtk4-devel
libadwaita-devel
pkgconf

# === UTILITIES ===
git
wget
curl
nano
htop
fastfetch
zsh
fish
zsh-syntax-highlighting
zsh-autosuggestions

# === CLEANUP (The "Kill List") ===
-anaconda*
-initial-setup*
# CRITICAL: Remove Fedora identity so Apex identity can take over
-fedora-release
-fedora-release-identity*
-generic-release
%end

%post --erroronfail
# 1. CONFIGURE DNF
cat > /etc/dnf/dnf.conf <<EOF
[main]
gpgcheck=1
installonly_limit=3
clean_requirements_on_remove=True
best=False
skip_if_unavailable=True
max_parallel_downloads=10
minrate=100k
timeout=10
fastestmirror=True
keepcache=True
EOF

# 2. TERRA PRIORITY FIX
# Ensure Terra doesn't overwrite core system files unless necessary
dnf config-manager --save --setopt=terra.priority=90

# 3. DRACUT CONFIG (For Live Boot)
echo 'add_dracutmodules+=" network livenet "' > /etc/dracut.conf.d/apex-live.conf

# 4. CREATE LIVE USER
useradd -m -c "Live System User" liveuser
passwd -d liveuser > /dev/null
usermod -aG wheel liveuser

# 5. SUDOERS SETUP
echo "%wheel ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/wheel
chmod 0440 /etc/sudoers.d/wheel

# 6. CLEANUP
dnf clean all
%end
