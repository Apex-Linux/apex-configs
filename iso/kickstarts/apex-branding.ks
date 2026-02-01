# === APEX LINUX BRANDING (Definitive Edition) ===
# Features: Split-Stage Network (Fixes DNS Error), Nuclear Replacement, Fail-Fast

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

# === STEP 1: THE HEIST (Download Outside the Jail) ===
# CRITICAL FIX: We use --nochroot. This runs on the BUILDER (which has internet).
# We clone directly into the image's /tmp directory ($INSTALL_ROOT/tmp).
%post --nochroot --erroronfail
set -e
echo ">>> [HOST] STARTING ASSET DOWNLOAD (NOCHROOT) <<<"

# 1. Clean any previous run
rm -rf $INSTALL_ROOT/tmp/apex-assets

# 2. Clone the repo (Using Host Network)
# This fixes "Could not resolve host: github.com"
git clone --depth 1 https://github.com/Apex-Linux/apex-configs.git $INSTALL_ROOT/tmp/apex-assets

# 3. Verify the loot (Fail fast if empty)
if [ ! -f $INSTALL_ROOT/tmp/apex-assets/iso/branding/logo.txt ]; then
    echo "❌ [HOST] ERROR: Download failed. logo.txt missing!"
    exit 1
fi

echo ">>> [HOST] ASSETS STAGED SUCCESSFULLY <<<"
%end

# === STEP 2: INSTALLATION (Inside the Jail) ===
# Now we are inside the image. We don't need internet anymore.
%post --erroronfail
set -e
echo ">>> [CHROOT] INSTALLING ASSETS <<<"

# 1. Verify Staged Assets
[ -d /tmp/apex-assets ] || { echo "❌ [CHROOT] Assets not found in /tmp!"; exit 1; }

# 2. Create System Directories
mkdir -p /usr/share/apex-linux/
mkdir -p /usr/share/calamares/branding/apex/

# 3. Install Assets (Exact Repo Files)
# We copy EVERYTHING from your calamares folder (squid.png, welcome.png, branding.desc)
cp -f /tmp/apex-assets/iso/branding/calamares/* /usr/share/calamares/branding/apex/
cp -f /tmp/apex-assets/iso/branding/logo.txt /usr/share/apex-linux/logo.txt

# 4. SELF-HEALING: Patch branding.desc if 'slideshow' is missing
# (Your repo might be missing this key, so we auto-add it to prevent a crash)
if ! grep -q "slideshow:" /usr/share/calamares/branding/apex/branding.desc; then
    echo "⚠️ [CHROOT] Patching missing 'slideshow' key in branding.desc..."
    echo 'slideshow: "show.qml"' >> /usr/share/calamares/branding/apex/branding.desc
fi

# Cleanup
rm -rf /tmp/apex-assets
echo ">>> [CHROOT] ASSETS INSTALLED <<<"
%end

# === STEP 3: IDENTITY SURGERY (The Nobara Method) ===
%post --erroronfail
set -e
echo ">>> [CHROOT] PERFORMING IDENTITY SURGERY <<<"

# 1. Hack os-release (Deep Identity Change)
sed -i 's/^NAME=.*$/NAME="Apex Linux"/' /etc/os-release
sed -i 's/^ID=.*$/ID=apex/' /etc/os-release
sed -i 's/^PRETTY_NAME=.*$/PRETTY_NAME="Apex Linux 2026"/' /etc/os-release
# IMPORTANT: Keep ID_LIKE=fedora so DNF and Drivers still work!
sed -i 's/^ID_LIKE=.*$/ID_LIKE="fedora"/' /etc/os-release
sed -i 's/^HOME_URL=.*$/HOME_URL="https:\/\/github.com\/Apex-Linux"/' /etc/os-release

# 2. Hack Login Screen Text
echo -e "Apex Linux 2026.1 \n \l" > /etc/issue
echo ">>> [CHROOT] SYSTEM IDENTITY UPDATED <<<"
%end

# === STEP 4: VISUAL SEARCH & DESTROY (The Nuke) ===
%post --erroronfail
set -e
echo ">>> [CHROOT] REPLACING FEDORA LOGOS <<<"

SOURCE_ICON="/usr/share/calamares/branding/apex/squid.png"

# Find ANY file with 'fedora' and 'logo' in the name and overwrite it.
# This covers start menus, plymouth themes, and random icons.
find /usr/share/pixmaps /usr/share/icons -type f \( -name "*fedora*logo*.png" -o -name "*fedora*logo*.svg" -o -name "*system-logo*.png" \) | while read -r FILE; do
    if [ -f "$FILE" ]; then
        # echo "  -> Nuking $FILE"
        cp -f "$SOURCE_ICON" "$FILE"
    fi
done

# Force Icon Cache Update
gtk-update-icon-cache -f /usr/share/icons/hicolor/ || true
echo ">>> [CHROOT] FEDORA VISUALS ERADICATED <<<"
%end

# === STEP 5: ASCII INTERCEPTOR (Fastfetch Hijack) ===
%post --erroronfail
set -e
echo ">>> [CHROOT] INSTALLING ASCII INTERCEPTOR <<<"

# 1. Master Config
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
# This is cleaner than replacing the binary. It survives updates.
cat > /usr/local/bin/fastfetch << 'EOF'
#!/bin/bash
exec /usr/bin/fastfetch --config /usr/share/fastfetch/presets/apex.jsonc "$@"
EOF
chmod +x /usr/local/bin/fastfetch

# 3. Hijack Neofetch (Legacy Support)
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

# A. Cleanup Defaults
rm -rf /usr/share/calamares/branding/fedora
rm -rf /usr/share/calamares/branding/default

# B. Partition Config (Btrfs Default + Choices)
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

# C. User Config
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

# D. QML Files (Qt6 Modern Standard)
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

# E. Settings.conf (Sequence)
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

# F. Desktop Shortcut (Using squid.png from repo)
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
