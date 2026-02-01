# === APEX LINUX BRANDING (DNS Injection 2026) ===
# Strategy: Inject DNS -> Clone Inside -> Install -> Cleanup

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

# === STEP 1: ASSET INJECTION & DEBUGGING ===
%post --erroronfail
set -e # Die immediately if any command fails

echo ">>> [CHROOT] STARTING ASSET INJECTION <<<"

# 1. FIX DNS (The "Blindness" Fix)
# The chroot has no DNS by default. We force Google DNS so we can find GitHub.
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 1.1.1.1" >> /etc/resolv.conf

# 2. CLONE REPO (With Debugging)
echo ">>> Cloning Apex Configs..."
rm -rf /tmp/apex-assets

# We use 'git clone' with verbose output.
# If this fails, we catch the error and print the network status.
if ! git clone --depth 1 --verbose https://github.com/Apex-Linux/apex-configs.git /tmp/apex-assets; then
    echo "❌ [ERROR] Git Clone Failed!"
    echo "--- NETWORK DEBUG ---"
    cat /etc/resolv.conf
    curl -I https://github.com
    exit 1
fi

# 3. VERIFY DOWNLOAD (Did we get the files?)
echo ">>> Verifying Downloaded Files..."
if [ ! -f /tmp/apex-assets/iso/branding/logo.txt ]; then
    echo "❌ [ERROR] Clone succeeded but files are missing!"
    echo "Contents of /tmp/apex-assets:"
    ls -R /tmp/apex-assets
    exit 1
fi

echo "✅ Repo cloned successfully. Files are present."

# 4. INSTALL ASSETS
mkdir -p /usr/share/apex-linux/
mkdir -p /usr/share/calamares/branding/apex/

echo ">>> Installing Logo & Calamares Assets..."
cp -f /tmp/apex-assets/iso/branding/calamares/* /usr/share/calamares/branding/apex/
cp -f /tmp/apex-assets/iso/branding/logo.txt /usr/share/apex-linux/logo.txt

# 5. SELF-HEALING (Patch branding.desc)
if ! grep -q "slideshow:" /usr/share/calamares/branding/apex/branding.desc; then
    echo "⚠️ Patching missing 'slideshow' key in branding.desc..."
    echo 'slideshow: "show.qml"' >> /usr/share/calamares/branding/apex/branding.desc
fi

# 6. CLEANUP
rm -rf /tmp/apex-assets
rm -f /etc/resolv.conf # Remove Google DNS so we don't leak it to the user
echo ">>> [CHROOT] ASSETS INSTALLED & CLEANED UP <<<"
%end

# === STEP 2: IDENTITY SURGERY ===
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

# === STEP 3: VISUAL SEARCH & DESTROY ===
%post --erroronfail
set -e
echo ">>> [CHROOT] REPLACING FEDORA LOGOS <<<"

SOURCE_ICON="/usr/share/calamares/branding/apex/squid.png"

# Find and overwrite Fedora logos
find /usr/share/pixmaps /usr/share/icons -type f \( -name "*fedora*logo*.png" -o -name "*fedora*logo*.svg" -o -name "*system-logo*.png" \) | while read -r FILE; do
    if [ -f "$FILE" ]; then
        cp -f "$SOURCE_ICON" "$FILE"
    fi
done

gtk-update-icon-cache -f /usr/share/icons/hicolor/ || true
echo ">>> [CHROOT] FEDORA VISUALS ERADICATED <<<"
%end

# === STEP 4: ASCII INTERCEPTOR ===
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

# Hijack fastfetch
cat > /usr/local/bin/fastfetch << 'EOF'
#!/bin/bash
exec /usr/bin/fastfetch --config /usr/share/fastfetch/presets/apex.jsonc "$@"
EOF
chmod +x /usr/local/bin/fastfetch

# Hijack neofetch
cat > /usr/bin/neofetch << 'EOF'
#!/bin/bash
exec /usr/local/bin/fastfetch "$@"
EOF
chmod +x /usr/bin/neofetch

echo ">>> [CHROOT] INTERCEPTOR ACTIVE <<<"
%end

# === STEP 5: CALAMARES CONFIGURATION ===
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
