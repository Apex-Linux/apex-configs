# === APEX LINUX BRANDING (Visual & Logic Repair) ===
# Fixes: Window Size, Sidebar Layout, Autostart Logic, Live User Theme

%packages
calamares
qt6-qtsvg
git
fastfetch
plymouth-plugin-script
findutils
sed
ImageMagick
wget
tar
# CRITICAL DEPENDENCIES
gcc
libadwaita-devel
gtk4-devel
papirus-icon-theme
potrace

%end

# === STEP 1: ASSET INJECTION & COMPILATION ===
%post --erroronfail
set -e
echo ">>> [CHROOT] STARTING ASSET INJECTION <<<"

# 1. FIX DNS
rm -f /etc/resolv.conf
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 1.1.1.1" >> /etc/resolv.conf

# 2. CLONE REPO
rm -rf /tmp/apex-assets
if ! git clone --depth 1 --verbose https://github.com/Apex-Linux/apex-configs.git /tmp/apex-assets; then
    echo "❌ [CHROOT] Git Clone Failed!"
    exit 1
fi

# 3. DOWNLOAD BIBATA
wget -O /tmp/apex-assets/Bibata.tar.xz https://github.com/ful1e5/Bibata_Cursor/releases/download/v2.0.7/Bibata-Modern-Ice.tar.xz

# 4. INSTALL ASSETS
mkdir -p /usr/share/apex-linux/
mkdir -p /usr/share/calamares/branding/apex/
cp -f /tmp/apex-assets/iso/branding/calamares/* /usr/share/calamares/branding/apex/
cp -f /tmp/apex-assets/iso/branding/logo.txt /usr/share/apex-linux/logo.txt

# 5. INSTALL BIBATA
tar -xf /tmp/apex-assets/Bibata.tar.xz -C /usr/share/icons/

# 6. COMPILE APEX UPDATER
echo ">>> Compiling Apex Updater..."
APP_SRC="/tmp/apex-assets/apps/apex-updater"
if [ -f "$APP_SRC/apex-updater.c" ]; then
    gcc -o /usr/bin/apex-updater "$APP_SRC/apex-updater.c" $(pkg-config --cflags --libs gtk4 libadwaita-1)
    cp "$APP_SRC/icon.png" /usr/share/pixmaps/apex-updater.png
    mkdir -p /usr/share/apex-updater
    cp "$APP_SRC/logo.png" /usr/share/apex-updater/logo.png
    
    cat > /usr/share/applications/apex-updater.desktop << 'EOF'
[Desktop Entry]
Name=Apex Updater
Comment=Update your Apex Linux System
Exec=apex-updater
Icon=apex-updater
Terminal=false
Type=Application
Categories=System;Settings;
StartupNotify=true
EOF
    
    # FIX: Move Autostart to /etc/skel (Only for new users, NOT Live USB)
    mkdir -p /etc/skel/.config/autostart
    ln -sf /usr/share/applications/apex-updater.desktop /etc/skel/.config/autostart/apex-updater.desktop
    echo "✅ Apex Updater Scheduled for New Users."
fi

# 7. CLEANUP
rm -rf /tmp/apex-assets
rm -f /etc/resolv.conf
echo ">>> [CHROOT] ASSETS INSTALLED <<<"
%end

# === STEP 2: THEME ENFORCER (GLOBAL + LIVE USER) ===
%post --erroronfail
set -e
echo ">>> [CHROOT] ENFORCING THEMES <<<"

# System Defaults
mkdir -p /usr/share/icons/default
cat > /usr/share/icons/default/index.theme << 'EOF'
[Icon Theme]
Inherits=Bibata-Modern-Ice
EOF

# GTK Settings
mkdir -p /etc/gtk-3.0
cat > /etc/gtk-3.0/settings.ini << 'EOF'
[Settings]
gtk-icon-theme-name=Papirus-Dark
gtk-cursor-theme-name=Bibata-Modern-Ice
gtk-theme-name=Adwaita-dark
EOF

# KDE Settings (Template for New Users)
mkdir -p /etc/skel/.config
cat > /etc/skel/.config/kcminputrc << 'EOF'
[Mouse]
cursorTheme=Bibata-Modern-Ice
cursorSize=24
EOF
cat >> /etc/skel/.config/kdeglobals << 'EOF'
[Icons]
Theme=Papirus-Dark
[General]
ColorScheme=BreezeDark
Name=Breeze Dark
EOF

# FIX: Force Settings onto the Live User IMMEDIATELY
if id "liveuser" &>/dev/null; then
    echo ">>> Applying themes to Live User..."
    mkdir -p /home/liveuser/.config
    cp /etc/skel/.config/kcminputrc /home/liveuser/.config/
    cp /etc/skel/.config/kdeglobals /home/liveuser/.config/
    chown -R liveuser:liveuser /home/liveuser
fi

# Apply to Root
mkdir -p /root/.config
cp /etc/skel/.config/kcminputrc /root/.config/
cp /etc/skel/.config/kdeglobals /root/.config/
%end

# === STEP 3: KDE DOCK & START MENU POLISH ===
%post --erroronfail
set -e
echo ">>> [CHROOT] POLISHING KDE <<<"
SQUID_ICON="/usr/share/calamares/branding/apex/squid.png"

# Remove Discover
LAYOUT_FILE="/usr/share/plasma/layout-templates/org.kde.plasma.desktop.defaultPanel/contents/layout.js"
if [ -f "$LAYOUT_FILE" ]; then
    sed -i '/org.kde.discover/d' "$LAYOUT_FILE"
    # Also remove system settings if desired, or keep it.
fi

# Brand Start Menu
if command -v magick >/dev/null 2>&1; then
    magick "$SQUID_ICON" /tmp/start-here.svg
    magick "$SQUID_ICON" -resize 48x48 /tmp/start-here.png
    find /usr/share/icons/Papirus-Dark -name "start-here*" -exec cp /tmp/start-here.svg {} \;
    cp /tmp/start-here.png /usr/share/pixmaps/start-here.png
    cp /tmp/start-here.png /usr/share/pixmaps/system-logo-white.png
fi
gtk-update-icon-cache -f /usr/share/icons/Papirus-Dark/ || true
%end

# === STEP 4: IDENTITY SURGERY ===
%post --erroronfail
set -e
sed -i 's/^NAME=.*$/NAME="Apex Linux"/' /etc/os-release
sed -i 's/^ID=.*$/ID=apex/' /etc/os-release
sed -i 's/^PRETTY_NAME=.*$/PRETTY_NAME="Apex Linux 2026"/' /etc/os-release
sed -i 's/^ID_LIKE=.*$/ID_LIKE="fedora"/' /etc/os-release
sed -i 's/^HOME_URL=.*$/HOME_URL="https:\/\/github.com\/Apex-Linux"/' /etc/os-release
echo -e "Apex Linux 2026.1 \n \l" > /etc/issue
%end

# === STEP 5: PLYMOUTH THEME (KERNEL FIX) ===
%post --erroronfail
set -e
echo ">>> [CHROOT] FIXING BOOT SPLASH <<<"
THEME_DIR="/usr/share/plymouth/themes/apex"
SPINNER_DIR="/usr/share/plymouth/themes/spinner"
SQUID_ICON="/usr/share/calamares/branding/apex/squid.png"

mkdir -p "$THEME_DIR"

if command -v magick >/dev/null 2>&1; then
    magick "$SQUID_ICON" -resize 150x150 "$THEME_DIR/watermark.png"
    magick "$SQUID_ICON" -resize 150x150 "$SPINNER_DIR/watermark.png"
    magick "$SQUID_ICON" -resize 150x150 "$SPINNER_DIR/fedora-logo-sprite.png"
else
    cp "$SQUID_ICON" "$THEME_DIR/watermark.png"
fi

cp -f "$SPINNER_DIR"/throbber-*.png "$THEME_DIR/" 2>/dev/null || true

cat > "$THEME_DIR/apex.plymouth" << 'EOF'
[Plymouth Theme]
Name=Apex Linux
ModuleName=script
[script]
ImageDir=/usr/share/plymouth/themes/apex
ScriptFile=/usr/share/plymouth/themes/apex/apex.script
EOF

cat > "$THEME_DIR/apex.script" << 'EOF'
logo_image = Image("watermark.png");
screen_width = Window.GetWidth();
screen_height = Window.GetHeight();
logo_x = (screen_width / 2) - (logo_image.GetWidth() / 2);
logo_y = (screen_height / 2) - (logo_image.GetHeight() / 2);
logo_sprite = Sprite(logo_image);
logo_sprite.SetPosition(logo_x, logo_y, 100);
EOF

plymouth-set-default-theme apex
KVER=$(ls /lib/modules | sort -V | tail -n 1)
dracut --force --kver "$KVER"
echo ">>> [CHROOT] PLYMOUTH FIXED <<<"
%end

# === STEP 6: VISUAL SEARCH & DESTROY ===
%post --erroronfail
set -e
SOURCE_ICON="/usr/share/calamares/branding/apex/squid.png"
find /usr/share/pixmaps /usr/share/icons -type f \( -name "*fedora*logo*.png" -o -name "*fedora*logo*.svg" -o -name "*system-logo*.png" \) | while read -r FILE; do
    cp -f "$SOURCE_ICON" "$FILE"
done
gtk-update-icon-cache -f /usr/share/icons/hicolor/ || true
%end

# === STEP 7: ASCII INTERCEPTOR ===
%post --erroronfail
set -e
mkdir -p /usr/share/fastfetch/presets
cat > /usr/share/fastfetch/presets/apex.jsonc << 'EOF'
{
  "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
  "logo": { "source": "/usr/share/apex-linux/logo.txt", "type": "file", "color": {"1": "blue"}, "padding": {"top": 1, "left": 2} },
  "modules": [ "title", "separator", "os", "host", "kernel", "uptime", "packages", "shell", "de", "memory", "break", "colors" ]
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
%end

# === STEP 8: CALAMARES UI POLISH (LAYOUT FIX) ===
%post --erroronfail
set -e
echo ">>> [CHROOT] CONFIGURING CALAMARES UI <<<"
rm -rf /usr/share/calamares/branding/fedora
rm -rf /usr/share/calamares/branding/default

# Branding Desc
cat > /usr/share/calamares/branding/apex/branding.desc << 'EOF'
---
componentName:  apex
welcomeStyleCalamares:   true
welcomeExpandingLogo:   true
windowExpanding:    normal
windowSize: 1024px,720px
windowPlacement: center
sidebar: qml,bottom
navigation: qml,right
strings:
    productName:         "Apex Linux"
    shortProductName:    "Apex"
    version:             "2026.1"
    shortVersion:        "2026.1"
    versionedName:       "Apex Linux 2026.1"
    shortVersionedName:  "Apex 2026"
    bootloaderEntryName: "Apex Linux"
    productUrl:          "https://github.com/Apex-Linux"
    supportUrl:          "https://github.com/Apex-Linux"
    knownIssuesUrl:      "https://github.com/Apex-Linux"
    releaseNotesUrl:     "https://github.com/Apex-Linux"
    donateUrl:           "https://github.com/Apex-Linux"
images:
    productLogo:         "squid.png"
    productIcon:         "squid.png"
    productWelcome:      "welcome.png"
slideshow:               "show.qml"
style:
   sidebarBackground:    "#2D3748"
   sidebarText:          "#A0AEC0"
   sidebarTextCurrent:   "#FFFFFF"
   sidebarBackgroundCurrent: "#4FD1C5"
EOF

# Sidebar
# FIX: Explicit anchors to prevent sidebar disappearing
cat > /usr/share/calamares/branding/apex/sidebar.qml << 'EOF'
import QtQuick
import calamares.branding 1.0
Rectangle {
    id: sidebar
    width: 200
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    color: Branding.styleString(Branding.SidebarBackground)
    Column {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 20
        Image {
            id: logo
            source: Branding.image(Branding.ProductLogo)
            width: 150; height: 150
            anchors.horizontalCenter: parent.horizontalCenter
            fillMode: Image.PreserveAspectFit
            smooth: true
        }
        Repeater {
            model: Branding.viewSteps
            delegate: Text {
                text: model.display
                color: model.current ? Branding.styleString(Branding.SidebarTextCurrent) : Branding.styleString(Branding.SidebarText)
                font.pixelSize: 16
                font.bold: model.current
                anchors.horizontalCenter: parent.horizontalCenter
                wrapMode: Text.WordWrap
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}
EOF

# Slideshow
cat > /usr/share/calamares/branding/apex/show.qml << 'EOF'
import QtQuick
import calamares.slideshow 1.0
Presentation {
    id: presentation
    Timer { interval: 5000; running: true; repeat: true; onTriggered: presentation.goToNextSlide() }
    Rectangle { anchors.fill: parent; color: "#1A202C" }
    Slide {
        anchors.fill: parent
        Text {
            anchors.centerIn: parent
            text: "Welcome to Apex Linux<br/><br/>Fast. Beautiful. Yours."
            color: "white"
            font.pixelSize: 24
            horizontalAlignment: Text.AlignCenter
        }
    }
}
EOF

# Partitioning
cat > /etc/calamares/modules/partition.conf << 'EOF'
efiSystemPartition: "/boot/efi"
efiSystemPartitionSize: 1024M
userSwapChoices: [none, small, suspend, file]
drawNestedPartitions: false
alwaysShowPartitionLabels: true
allowManualPartitioning: true
defaultPartitionTableType: "gpt"
initialPartitioningChoice: erase
initialSwapChoice: none
defaultFileSystemType: "btrfs"
availableFileSystemTypes: ["btrfs", "ext4", "xfs", "f2fs"]
EOF

cat > /etc/calamares/modules/users.conf << 'EOF'
defaultGroups: [wheel, lp, video, network, storage, optical, audio, input]
autologinGroup: liveuser
doAutologin: false
sudoersGroup: wheel
setRootPassword: false
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
- show: [welcome, locale, keyboard, partition, users, summary]
- exec: [partition, mount, unpackfs, machineid, fstab, locale, keyboard, localecfg, users, networkcfg, hwclock, services-systemd, packages, grubcfg, bootloader, umount]
- show: [finished]
branding: apex
prompt-install: false
dont-chroot: false
oem-setup: false
disable-cancel: false
disable-cancel-during-exec: false
hide-back-and-next-during-exec: false
quit-at-end: false
EOF

# Desktop Shortcut
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
