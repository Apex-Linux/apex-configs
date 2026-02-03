# === APEX LINUX ROOT (Ultimate Edition) ===
# Description: Peak Feature Set with HW Detection Tools

lang en_US.UTF-8
keyboard us
timezone UTC
selinux --enforcing
firewall --enabled --service=mdns
xconfig --startxonboot
zerombr
clearpart --all --initlabel

# === LIVE STORAGE ===
part / --size 12288 --fstype ext4
rootpw --lock --iscrypted locked
bootloader --append="rd.live.check=0 rhgb quiet zram.num_devices=1"

# === REPOSITORIES ===
network --bootproto=dhcp --device=link --activate
url --mirrorlist=https://mirrors.fedoraproject.org/metalink?repo=fedora-43&arch=$basearch
repo --name=updates --mirrorlist=https://mirrors.fedoraproject.org/metalink?repo=updates-released-f43&arch=$basearch
repo --name=apex-core --baseurl=https://download.copr.fedorainfracloud.org/results/ackerman/apex-core/fedora-$releasever-$basearch/ --cost=50
repo --name=terra --baseurl=https://repos.fyralabs.com/terra$releasever --cost=60 --noverifyssl

# === PACKAGES ===
%packages
# 1. KERNEL & BOOT
kernel
kernel-modules
kernel-modules-extra
linux-firmware
grub2-efi-x64
shim-x64
efibootmgr
grub2-efi-x64-cdboot

# 2. HW DETECTION TOOLS (CRITICAL)
pciutils            # lspci
usbutils            # lsusb
dmidecode           # Laptop detection
lshw                # Detailed HW info
smartmontools

# 3. PERFORMANCE & ZRAM
zram-generator
zram-generator-defaults
irqbalance
power-profiles-daemon

# 4. FILESYSTEM & RECOVERY
btrfs-progs
xfsprogs
f2fs-tools
cryptsetup
lvm2
gparted
testdisk
nvme-cli
hdparm

# 5. VIRTUALIZATION GUEST TOOLS
qemu-guest-agent
open-vm-tools-desktop
hyperv-daemons

# 6. MINIMAL KDE (Live Session)
plasma-desktop
plasma-workspace-wayland
sddm
kwin
konsole
dolphin
plasma-nm
plasma-pa
pipewire-alsa
pipewire-pulseaudio

# 7. INSTALLER
calamares
libsForQt5-calamares
kde-partitionmanager
glibc-all-langpacks

# 8. IDENTITY
apex-release
terra-release
distribution-gpg-keys

# 9. VISUALS
papirus-icon-theme
plymouth
plymouth-system-theme
plymouth-plugin-script

# 10. CLEANUP
-office-suite
-media-player
-firefox
-thunderbird
-plasma-welcome
-fedora-release
-generic-release
-abrt*
%end

# === POST CONFIG ===
%include apex-branding.ks

%post --erroronfail
# DNF Optimization
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

# Live User
useradd -m -c "Live System User" liveuser
passwd -d liveuser > /dev/null
usermod -aG wheel liveuser
echo "%wheel ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/wheel

# Services
systemctl enable sddm NetworkManager bluetooth zram-setup@zram0.service

# Autostart Calamares
mkdir -p /home/liveuser/.config/autostart
cat > /home/liveuser/.config/autostart/calamares-launch.desktop <<EOF
[Desktop Entry]
Type=Application
Name=Install Apex Linux
Exec=sh -c "sleep 5 && calamares"
Icon=calamares
Terminal=false
EOF
chown -R liveuser:liveuser /home/liveuser

# Cleanup
rm -f /home/liveuser/.config/autostart/apex-updater.desktop
dnf clean all
%end
