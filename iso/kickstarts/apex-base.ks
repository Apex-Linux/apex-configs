# === APEX LINUX BASE (Speed & Freshness Edition) ===
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

# NETWORK & REPOS
network --bootproto=dhcp --device=link --activate
url --mirrorlist=https://mirrors.fedoraproject.org/metalink?repo=fedora-43&arch=$basearch
repo --name=updates --mirrorlist=https://mirrors.fedoraproject.org/metalink?repo=updates-released-f43&arch=$basearch

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

# LIVE TOOLS
dracut-live
dracut-network
dracut-config-generic
livesys-scripts
plymouth
plymouth-system-theme

# === MANUAL PARTITIONING TOOLS ===
kde-partitionmanager
btrfs-progs
xfsprogs
e2fsprogs
dosfstools
ntfs-3g
fuse
f2fs-tools

# === SHELLS ===
zsh
fish
zsh-syntax-highlighting
zsh-autosuggestions

# UTILITIES
git
wget
curl
nano
htop
fastfetch

# REMOVE ANACONDA
-anaconda*
-initial-setup*
%end

%post --erroronfail
# === 1. INJECT DNF SPEED TWEAKS ===

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

echo ">>> DNF SPEED TWEAKS APPLIED <<<"

# === 2. FORCE KERNEL UPDATE ===
echo ">>> FORCING SYSTEM UPDATE TO LATEST KERNEL <<<"
dnf update -y

# === 3. IDENTITY ===
sed -i 's/^NAME=.*$/NAME="Apex Linux"/' /etc/os-release
sed -i 's/^PRETTY_NAME=.*$/PRETTY_NAME="Apex Linux"/' /etc/os-release
sed -i 's/^ID=.*$/ID=apex/' /etc/os-release
echo -e "Apex Linux \n \l" > /etc/issue

# === 4. DRACUT NETWORK FIX ===
echo 'add_dracutmodules+=" network livenet "' > /etc/dracut.conf.d/apex-live.conf

# === 5. SERVICES ===
systemctl enable ModemManager || true
systemctl mask speech-dispatcherd || true

# === 6. USER SETUP ===
useradd -m -c "Live System User" liveuser
passwd -d liveuser > /dev/null
usermod -aG wheel liveuser
echo "%wheel ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/wheel
chmod 0440 /etc/sudoers.d/wheel

# === 7. CLEANUP (CRITICAL) ===
# Since you set keepcache=True, we MUST clean it here or your ISO will be huge.
# The user will still have the dnf.conf settings, just not the dirty cache.
dnf clean all

%end
