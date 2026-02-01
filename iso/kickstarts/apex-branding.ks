# === APEX LINUX BRANDING (Nuclear Edition 2026) ===
# Features: Identity Surgery, Search & Destroy, Fail-Fast, ASCII Enforcement

%packages
calamares
qt6-qtsvg
git
fastfetch
plymouth-plugin-script
# Essential for finding and replacing files
findutils
sed
# ImageMagick allows resizing if we ever need it (Legacy safety)
ImageMagick
%end

# === STEP 1: ASSET INJECTION (Fail-Safe Mode) ===
%post --erroronfail
set -e  # <--- FALLBACK: Any error stops the build INSTANTLY.

echo ">>> STARTING ASSET INJECTION <<<"

# 1. Clone Repo
git clone --depth 1 https://github.com/Apex-Linux/apex-configs.git /tmp/apex-assets

# 2. Verify Assets (If missing, we DIE here)
[ -f /tmp/apex-assets/iso/branding/logo.txt ] || { echo "❌ ERROR: logo.txt missing"; exit 1; }
[ -f /tmp/apex-assets/iso/branding/calamares/squid.png ] || { echo "❌ ERROR: squid.png missing"; exit 1; }
[ -f /tmp/apex-assets/iso/branding/calamares/welcome.png ] || { echo "❌ ERROR: welcome.png missing"; exit 1; }
[ -f /tmp/apex-assets/iso/branding/calamares/branding.desc ] || { echo "❌ ERROR: branding.desc missing"; exit 1; }

# 3. Create Directories
mkdir -p /usr/share/apex-linux/
mkdir -p /usr/share/calamares/branding/apex/

# 4. Install Assets (Exact Repo Files)
cp -f /tmp/apex-assets/iso/branding/calamares/* /usr/share/calamares/branding/apex/
cp -f /tmp/apex-assets/iso/branding/logo.txt /usr/share/apex-linux/logo.txt

# 5. SELF-HEALING: Patch branding.desc if keys are missing
if ! grep -q "slideshow:" /usr/share/calamares/branding/apex/branding.desc; then
    echo "⚠️ WARNING: branding.desc missing slideshow key. Patching it..."
    echo 'slideshow: "show.qml"' >> /usr/share/calamares/branding/apex/branding.desc
fi

# Cleanup
rm -rf /tmp/apex-assets
echo ">>> ASSETS INJECTED & VERIFIED <<<"
%end

# === STEP 2: THE IDENTITY SURGERY (Root Rebrand) ===
%post --erroronfail
set -e

echo ">>> PERFORMING SYSTEM IDENTITY SURGERY <<<"

# 1. Hack os-release (This makes tools think the OS is Apex)
# We modify both locations to be safe.
sed -i 's/^NAME=.*$/NAME="Apex Linux"/' /etc/os-release
sed -i 's/^ID=.*$/ID=apex/' /etc/os-release
sed -i 's/^PRETTY_NAME=.*$/PRETTY_NAME="Apex Linux 2026"/' /etc/os-release
# Keep ID_LIKE=fedora so dnf still works!
sed -i 's/^ID_LIKE=.*$/ID_LIKE="fedora"/' /etc/os-release
sed -i 's/^HOME_URL=.*$/HOME_URL="https:\/\/github.com\/Apex-Linux"/' /etc/os-release

# 2. Hack the Login Text (/etc/issue)
echo -e "Apex Linux 2026.1 \n \l" > /etc/issue
echo -e "Apex Linux 2026.1" > /etc/issue.net

echo ">>> IDENTITY CHANGE COMPLETE <<<"
%end

# === STEP 3: VISUAL SEARCH & DESTROY (The Nuke) ===
%post --erroronfail
set -e

echo ">>> INITIATING VISUAL SEARCH & DESTROY <<<"

# 1. Define the Source Image
SOURCE_ICON="/usr/share/calamares/branding/apex/squid.png"

# 2. The Loop: Find ANY Fedora logo and kill it
# We look in pixmaps and icons. We overwrite them with squid.png.
find /usr/share/pixmaps /usr/share/icons -type f \( -name "*fedora*logo*.png" -o -name "*fedora*logo*.svg" -o -name "*system-logo*.png" \) | while read -r FILE; do
    echo "  -> Nuking $FILE"
    cp -f "$SOURCE_ICON" "$FILE"
done

# 3. Update Icon Cache
gtk-update-icon-cache -f /usr/share/icons/hicolor/ || true

echo ">>> FEDORA BRANDING ERADICATED <<<"
%end

# === STEP 4: ASCII INTERCEPTOR (Force Logic) ===
%post --erroronfail
set -e

# 1. Create the Master Config
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

# 2. Hijack /usr/local/bin/fastfetch
# This ensures that even if 'ID=apex' confuses fastfetch, our config overrides it.
cat > /usr/local/bin/fastfetch << 'EOF'
#!/bin/bash
exec /usr/bin/fastfetch --config /usr/share/fastfetch/presets/apex.jsonc "$@"
EOF
chmod +x /usr/local/bin/fastfetch

# 3. Hijack Neofetch
cat > /usr/bin/neofetch << 'EOF'
#!/bin/bash
exec /usr/local/bin/fastfetch "$@"
EOF
chmod +x /usr/bin/neofetch

echo ">>> ASCII INTERCEPTOR ACTIVE <<<"
%end

# === STEP 5: CALAMARES CONFIGURATION ===
%post --erroronfail
set -e

# A. Cleanup Defaults
rm -rf /usr/share/calamares/branding/fedora
rm -rf /usr/share/calamares/branding/default

# B. Manual Partitioning (Choice Enabled)
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

# C. User Module
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

# D. QML Files (Qt6)
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

# E. Settings.conf
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

# F. Desktop Shortcut
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

echo ">>> APEX BRANDING COMPLETE <<<"
%end
