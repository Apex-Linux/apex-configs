# === APEX LINUX BRANDING===

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
# Ensure Papirus is installed from repos
papirus-icon-theme
%end

# === STEP 1: ASSET INJECTION & COMPILATION (DNS Method) ===
%post --erroronfail
set -e
echo ">>> [CHROOT] STARTING ASSET INJECTION (DNS METHOD) <<<"

# 1. FIX DNS (Symlink Smash - Critical Fix)
rm -f /etc/resolv.conf
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 1.1.1.1" >> /etc/resolv.conf

# 2. CLONE REPO
echo ">>> Cloning Apex Configs..."
rm -rf /tmp/apex-assets
if ! git clone --depth 1 --verbose https://github.com/Apex-Linux/apex-configs.git /tmp/apex-assets; then
    echo "❌ [CHROOT] Git Clone Failed!"
    cat /etc/resolv.conf
    curl -I https://github.com
    exit 1
fi

# 3. DOWNLOAD BIBATA CURSOR (FIXED URL)
echo ">>> Downloading Bibata Cursor..."
# ERROR FIX: Changed extension from .tar.gz to .tar.xz
wget -O /tmp/apex-assets/Bibata.tar.xz https://github.com/ful1e5/Bibata_Cursor/releases/download/v2.0.7/Bibata-Modern-Ice.tar.xz

# 4. VERIFY DOWNLOADS
if [ ! -f /tmp/apex-assets/iso/branding/logo.txt ]; then
    echo "❌ [CHROOT] Logo missing!"
    exit 1
fi
if [ ! -f /tmp/apex-assets/Bibata.tar.xz ]; then
    echo "❌ [CHROOT] Bibata download failed! (Check URL/Network)"
    exit 1
fi

# 5. INSTALL ASSETS
echo ">>> Installing Branding Assets..."
mkdir -p /usr/share/apex-linux/
mkdir -p /usr/share/calamares/branding/apex/
cp -f /tmp/apex-assets/iso/branding/calamares/* /usr/share/calamares/branding/apex/
cp -f /tmp/apex-assets/iso/branding/logo.txt /usr/share/apex-linux/logo.txt

# 6. INSTALL BIBATA CURSOR
echo ">>> Installing Bibata..."
# ERROR FIX: Using 'tar -xf' which auto-detects .xz format
tar -xf /tmp/apex-assets/Bibata.tar.xz -C /usr/share/icons/

# 7. COMPILE & INSTALL APEX UPDATER
echo ">>> Compiling Apex Updater..."
APP_SRC="/tmp/apex-assets/apps/apex-updater"
if [ -f "$APP_SRC/apex-updater.c" ]; then
    # Compile
    gcc -o /usr/bin/apex-updater "$APP_SRC/apex-updater.c" $(pkg-config --cflags --libs gtk4)
    
    # Install Assets
    cp "$APP_SRC/icon.png" /usr/share/pixmaps/apex-updater.png
    mkdir -p /usr/share/apex-updater
    cp "$APP_SRC/logo.png" /usr/share/apex-updater/logo.png
    
    # Generate Desktop Entry
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
    
    # AUTOSTART (Run by default on login)
    echo ">>> Enabling Updater Autostart..."
    mkdir -p /etc/xdg/autostart
    ln -sf /usr/share/applications/apex-updater.desktop /etc/xdg/autostart/apex-updater.desktop
    
    echo "✅ Apex Updater Installed & Autostarted."
else
    echo "⚠️ Updater source code not found. Skipping."
fi

# 8. CLEANUP
rm -rf /tmp/apex-assets
rm -f /etc/resolv.conf
echo ">>> [CHROOT] ASSETS INSTALLED & NETWORK CLEANED <<<"
%end

# === STEP 2: THEME ENFORCER (Papirus & Bibata) ===
%post --erroronfail
set -e
echo ">>> [CHROOT] ENFORCING THEMES <<<"

# 1. System-Wide Defaults
mkdir -p /usr/share/icons/default
cat > /usr/share/icons/default/index.theme << 'EOF'
[Icon Theme]
Inherits=Bibata-Modern-Ice
EOF

# 2. GTK Settings
mkdir -p /etc/gtk-3.0
cat > /etc/gtk-3.0/settings.ini << 'EOF'
[Settings]
gtk-icon-theme-name=Papirus-Dark
gtk-cursor-theme-name=Bibata-Modern-Ice
gtk-theme-name=Adwaita-dark
EOF

# 3. KDE Plasma Settings
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

# 4. Root Settings
mkdir -p /root/.config
cp /etc/skel/.config/kcminputrc /root/.config/
cp /etc/skel/.config/kdeglobals /root/.config/

echo ">>> [CHROOT] THEMES LOCKED IN <<<"
%end

# === STEP 3: KDE DOCK & START MENU POLISH ===
%post --erroronfail
set -e
echo ">>> [CHROOT] POLISHING KDE DOCK & START MENU <<<"

SQUID_ICON="/usr/share/calamares/branding/apex/squid.png"

# 1. REMOVE DISCOVER FROM DEFAULT DOCK
LAYOUT_FILE="/usr/share/plasma/layout-templates/org.kde.plasma.desktop.defaultPanel/contents/layout.js"
if [ -f "$LAYOUT_FILE" ]; then
    echo ">>> Removing Discover from Default Panel..."
    sed -i '/org.kde.discover/d' "$LAYOUT_FILE"
fi

# 2. BRAND START MENU ICON (Squid)
echo ">>> Branding Start Menu with Squid..."
if command -v convert >/dev/null 2>&1; then
    convert "$SQUID_ICON" /tmp/start-here.svg
    convert "$SQUID_ICON" -resize 48x48 /tmp/start-here.png
    
    # Overwrite Papirus places
    find /usr/share/icons/Papirus-Dark -name "start-here*" -exec cp /tmp/start-here.svg {} \;
    # Overwrite Pixmaps (Backup)
    cp /tmp/start-here.png /usr/share/pixmaps/start-here.png
    cp /tmp/start-here.png /usr/share/pixmaps/system-logo-white.png
fi

gtk-update-icon-cache -f /usr/share/icons/Papirus-Dark/ || true
echo ">>> [CHROOT] KDE POLISHED <<<"
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

# === STEP 5: PLYMOUTH THEME (Resized & Fixed) ===
%post --erroronfail
set -e
echo ">>> [CHROOT] FIXING BOOT SPLASH <<<"
THEME_DIR="/usr/share/plymouth/themes/apex"
SPINNER_DIR="/usr/share/plymouth/themes/spinner"
SQUID_ICON="/usr/share/calamares/branding/apex/squid.png"

mkdir -p "$THEME_DIR"

# 1. Resize Logo (150x150)
if command -v convert >/dev/null 2>&1; then
    convert "$SQUID_ICON" -resize 150x150 "$THEME_DIR/watermark.png"
    convert "$SQUID_ICON" -resize 150x150 "$SPINNER_DIR/watermark.png"
    convert "$SQUID_ICON" -resize 150x150 "$SPINNER_DIR/fedora-logo-sprite.png"
else
    cp "$SQUID_ICON" "$THEME_DIR/watermark.png"
fi

# 2. Copy Spinners & Configs
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

# 3. Apply Theme
plymouth-set-default-theme -R apex
echo ">>> [CHROOT] PLYMOUTH FIXED <<<"
%end

# === STEP 6: VISUAL SEARCH & DESTROY ===
%post --erroronfail
set -e
echo ">>> [CHROOT] REPLACING RESIDUAL ICONS <<<"
SOURCE_ICON="/usr/share/calamares/branding/apex/squid.png"
find /usr/share/pixmaps /usr/share/icons -type f \( -name "*fedora*logo*.png" -o -name "*fedora*logo*.svg" -o -name "*system-logo*.png" \) | while read -r FILE; do
    cp -f "$SOURCE_ICON" "$FILE"
done
gtk-update-icon-cache -f /usr/share/icons/hicolor/ || true
%end

# === STEP 7: ASCII INTERCEPTOR (Fastfetch) ===
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

# === STEP 8: CALAMARES UI POLISH (Qt6 Modern + 1GB EFI) ===
%post --erroronfail
set -e
echo ">>> [CHROOT] CONFIGURING CALAMARES UI <<<"
rm -rf /usr/share/calamares/branding/fedora
rm -rf /usr/share/calamares/branding/default

# 1. Branding Desc (Dark Mode Colors)
cat > /usr/share/calamares/branding/apex/branding.desc << 'EOF'
---
componentName:  apex
welcomeStyleCalamares:   true
welcomeExpandingLogo:   true
windowExpanding:    normal
windowSize: 800px,520px
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

# 2. Sidebar (Qt6 Modern + Scaled Icon Fix)
cat > /usr/share/calamares/branding/apex/sidebar.qml << 'EOF'
import QtQuick
import calamares.branding 1.0
Rectangle {
    id: sidebar
    width: 200; height: 520
    color: Branding.styleString(Branding.SidebarBackground)
    Column {
        anchors.fill: parent; anchors.margins: 10; spacing: 20
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
            }
        }
    }
}
EOF

# 3. Slideshow (Qt6 Modern + Dark Background Fix)
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

# 4. Standard Configs (WITH 1GB EFI & GPT DEFAULT)
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

# 5. Desktop Shortcut
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
