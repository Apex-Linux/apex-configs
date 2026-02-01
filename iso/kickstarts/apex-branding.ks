# === APEX LINUX BRANDING (Persistence Fix 2026) ===
# Strategy: Split-Stage Network + Persistent Handoff (/opt)

%packages
calamares
qt6-qtsvg
git
fastfetch
plymouth-plugin-script
findutils
sed
ImageMagick
%end

# === STEP 1: THE HEIST (Download Outside) ===
# We use --nochroot to access the internet from the builder.
# We save to /opt because /tmp gets hidden by a RAM disk inside the chroot.
%post --nochroot --erroronfail
set -e
echo ">>> [HOST] STARTING ASSET DOWNLOAD (NOCHROOT) <<<"

# 1. Clone the repo directly into the image's /opt directory
# This directory persists into the chroot.
rm -rf $INSTALL_ROOT/opt/apex-assets
git clone --depth 1 https://github.com/Apex-Linux/apex-configs.git $INSTALL_ROOT/opt/apex-assets

# 2. Verify the loot
if [ ! -f $INSTALL_ROOT/opt/apex-assets/iso/branding/logo.txt ]; then
    echo "❌ [HOST] ERROR: Download failed. logo.txt missing!"
    exit 1
fi

echo ">>> [HOST] ASSETS STAGED IN /OPT <<<"
%end

# === STEP 2: INSTALLATION (Inside the Jail) ===
%post --erroronfail
set -e
echo ">>> [CHROOT] INSTALLING ASSETS <<<"

# 1. Verify Staged Assets in /opt
[ -d /opt/apex-assets ] || { echo "❌ [CHROOT] Assets not found in /opt!"; exit 1; }

# 2. Create System Directories
mkdir -p /usr/share/apex-linux/
mkdir -p /usr/share/calamares/branding/apex/

# 3. Install Assets
cp -f /opt/apex-assets/iso/branding/calamares/* /usr/share/calamares/branding/apex/
cp -f /opt/apex-assets/iso/branding/logo.txt /usr/share/apex-linux/logo.txt

# 4. Patch branding.desc
if ! grep -q "slideshow:" /usr/share/calamares/branding/apex/branding.desc; then
    echo "⚠️ [CHROOT] Patching missing 'slideshow' key..."
    echo 'slideshow: "show.qml"' >> /usr/share/calamares/branding/apex/branding.desc
fi

# Cleanup the staging area
rm -rf /opt/apex-assets
echo ">>> [CHROOT] ASSETS INSTALLED <<<"
%end

# === STEP 3: IDENTITY SURGERY ===
%post --erroronfail
set -e
echo ">>> [CHROOT] PERFORMING IDENTITY SURGERY <<<"

sed -i 's/^NAME=.*$/NAME="Apex Linux"/' /etc/os-release
sed -i 's/^ID=.*$/ID=apex/' /etc/os-release
sed -i 's/^PRETTY_NAME=.*$/PRETTY_NAME="Apex Linux 2026"/' /etc/os-release
sed -i 's/^ID_LIKE=.*$/ID_LIKE="fedora"/' /etc/os-release
sed -i 's/^HOME_URL=.*$/HOME_URL="https:\/\/github.com\/Apex-Linux"/' /etc/os-release
echo -e "Apex Linux 2026.1 \n \l" > /etc/issue

echo ">>> [CHROOT] IDENTITY CHANGED <<<"
%end

# === STEP 4: VISUAL SEARCH & DESTROY ===
%post --erroronfail
set -e
echo ">>> [CHROOT] REPLACING FEDORA LOGOS <<<"

SOURCE_ICON="/usr/share/calamares/branding/apex/squid.png"

find /usr/share/pixmaps /usr/share/icons -type f \( -name "*fedora*logo*.png" -o -name "*fedora*logo*.svg" -o -name "*system-logo*.png" \) | while read -r FILE; do
    if [ -f "$FILE" ]; then
        cp -f "$SOURCE_ICON" "$FILE"
    fi
done

gtk-update-icon-cache -f /usr/share/icons/hicolor/ || true
echo ">>> [CHROOT] FEDORA VISUALS ERADICATED <<<"
%end

# === STEP 5: ASCII INTERCEPTOR ===
%post --erroronfail
set -e
echo ">>> [CHROOT] INSTALLING ASCII INTERCEPTOR <<<"

mkdir -p /usr/share/fastfetch/presets
cat > /usr/share/fastfetch/presets/apex.jsonc << 'EOF'
{
  "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
  "logo": {
    "source": "/usr/share/apex-linux/logo.txt",
    "type": "file",
    "color": { "1": "blue" },
    "padding": { "top": 1, "left": 2 }
  },
  "display": {
    "separator": "  ->  ",
    "color": "blue"
  },
  "modules": [
    "title", "separator", "os", "host", "kernel", "uptime", "packages", "shell", "de", "memory", "disk", "break", "colors"
  ]
}
EOF

cat > /usr/local/bin/fastfetch << 'EOF'
#!/bin/bash
exec /usr/bin/fastfetch --config /usr/share/fastfetch/presets/apex.jsonc "$@"
EOF
chmod +x /usr/local/bin/fastfetch

cat > /usr/bin/neofetch << 'EOF'
#!/bin/bash
exec /usr/local/bin/fastfetch "$@"
EOF
chmod +x /usr/bin/neofetch

echo ">>> [CHROOT] INTERCEPTOR ACTIVE <<<"
%end

# === STEP 6: CALAMARES CONFIGURATION ===
%post --erroronfail
set -e
echo ">>> [CHROOT] CONFIGURING CALAMARES <<<"

rm -rf /usr/share/calamares/branding/fedora
rm -rf /usr/share/calamares/branding/default

cat > /etc/calamares/modules/partition.conf << 'EOF'
efiSystemPartition: "/boot/efi"
userSwapChoices:
    - none
    - small
    - suspend
    - file
drawNestedPartitions: false
alwaysShowPartitionLabels: true
allowManualPartitioning: true
initialPartitioningChoice: erase
initialSwapChoice: none
defaultFileSystemType: "btrfs"
availableFileSystemTypes: ["btrfs", "ext4", "xfs", "f2fs"]
EOF

cat > /etc/calamares/modules/users.conf << 'EOF'
defaultGroups:
    - wheel
    - lp
    - video
    - network
    - storage
    - optical
    - audio
    - input
autologinGroup: liveuser
doAutologin: false
sudoersGroup: wheel
setRootPassword: false
EOF

cat > /usr/share/calamares/branding/apex/show.qml << 'EOF'
import QtQuick
import calamares.slideshow 1.0

Presentation {
    id: presentation
    Timer {
        interval: 5000; running: true; repeat: true
        onTriggered: presentation.goToNextSlide()
    }
    Slide {
        anchors.fill: parent
        Text {
            anchors.centerIn: parent
            text: "Welcome to Apex Linux<br/><br/>The installation will start shortly."
            color: "white"
            font.pixelSize: 24
            horizontalAlignment: Text.AlignCenter
        }
    }
}
EOF

cat > /etc/calamares/settings.conf << 'EOF'
modules-search: [ local ]
instances:
- id:       before
  module:   contextualprocess
  config:   contextualprocess-before.conf
- id:       after
  module:   contextualprocess
  config:   contextualprocess-after.conf
sequence:
- show:
  - welcome
  - locale
  - keyboard
  - partition
  - users
  - summary
- exec:
  - partition
  - mount
  - unpackfs
  - machineid
  - fstab
  - locale
  - keyboard
  - localecfg
  - users
  - networkcfg
  - hwclock
  - services-systemd
  - packages
  - grubcfg
  - bootloader
  - umount
- show:
  - finished
branding: apex
prompt-install: false
dont-chroot: false
oem-setup: false
disable-cancel: false
disable-cancel-during-exec: false
hide-back-and-next-during-exec: false
quit-at-end: false
EOF

mkdir -p /home/liveuser/.config/autostart
cat > /home/liveuser/.config/autostart/calamares.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=Install Apex Linux
GenericName=Live Installer
Exec=sudo -E calamares
Icon=/usr/share/calamares/branding/apex/squid.png
Terminal=false
StartupNotify=true
Categories=System;Qt;
EOF

mkdir -p /home/liveuser/Desktop
cp /home/liveuser/.config/autostart/calamares.desktop /home/liveuser/Desktop/install-apex.desktop
chmod +x /home/liveuser/Desktop/install-apex.desktop
chown -R liveuser:liveuser /home/liveuser

echo ">>> [CHROOT] BRANDING COMPLETE <<<"
%end
