# === APEX LINUX BRANDING (Qt6 + Git Injection) ===

%packages
calamares
qt6-qtsvg
git
fastfetch
plymouth-plugin-script
%end

# === STEP 1: DYNAMIC ASSET INJECTION ===
%post --erroronfail

echo ">>> INJECTING ASSETS FROM GITHUB <<<"
# We use --depth 1 to make the download instant.
# This eliminates "File Not Found" errors by pulling fresh from source.
git clone --depth 1 https://github.com/Apex-Linux/apex-configs.git /tmp/apex-assets

mkdir -p /usr/share/apex-linux/calamares

# Safe Copy (Force Overwrite)
cp -f /tmp/apex-assets/iso/branding/logo.txt /usr/share/apex-linux/
cp -f /tmp/apex-assets/iso/branding/calamares/squid.png /usr/share/apex-linux/calamares/
cp -f /tmp/apex-assets/iso/branding/calamares/welcome.png /usr/share/apex-linux/calamares/

# Cleanup
rm -rf /tmp/apex-assets
echo ">>> ASSETS INJECTED <<<"
%end

# === STEP 2: CONFIGURE SHELL (MODERN FASTFETCH) ===
%post --erroronfail
chmod -R 755 /usr/share/apex-linux

# Create a modern JSONC config for Fastfetch
mkdir -p /usr/share/fastfetch/presets
cat > /usr/share/fastfetch/presets/apex.jsonc << 'EOF'
{
  "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
  "logo": {
    "source": "/usr/share/apex-linux/logo.txt",
    "type": "file",
    "color": { "1": "blue" }
  },
  "modules": [
    "title", "separator", "os", "host", "kernel", "uptime", "packages", "shell", "de", "memory", "disk", "break", "colors"
  ]
}
EOF

# Apply globally
cat > /etc/profile.d/z99-apex.sh << 'EOF'
alias fastfetch='fastfetch --config /usr/share/fastfetch/presets/apex.jsonc'
alias neofetch='fastfetch --config /usr/share/fastfetch/presets/apex.jsonc'
EOF
chmod +x /etc/profile.d/z99-apex.sh
%end

# === STEP 3: CALAMARES BRANDING (Qt6 UPDATED) ===
%post --erroronfail

# A. CLEANUP
rm -rf /usr/share/calamares/branding/fedora
rm -rf /usr/share/calamares/branding/default
mkdir -p /usr/share/calamares/branding/apex

# B. IMAGES
cp /usr/share/apex-linux/calamares/squid.png /usr/share/calamares/branding/apex/squid.png
cp /usr/share/apex-linux/calamares/welcome.png /usr/share/calamares/branding/apex/welcome.png
# Use the logo as the icon too
cp /usr/share/apex-linux/calamares/squid.png /usr/share/calamares/branding/apex/icon.png

# C. BRANDING.DESC
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
    productIcon:         "icon.png"
    productWelcome:      "welcome.png"

slideshow:               "show.qml"
slideshowAPI:            1

style:
   sidebarBackground:    "#292f34"
   sidebarText:          "#FFFFFF"
   sidebarTextSelect:    "#292f34"
   sidebarTextHighlight: "#00BFFF"
EOF

# D. QML FILES (Qt6 COMPATIBLE - CRITICAL)
# In Qt6, "import QtQuick 2.0" is dead. Use "import QtQuick".

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

cat > /usr/share/calamares/branding/apex/navigation.qml << 'EOF'
import io.calamares.ui 1.0
import io.calamares.core 1.0
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: navigationBar;
    color: Branding.styleString( Branding.SidebarBackground );
    height: parent.height; width: 64;

    ColumnLayout {
        anchors.fill: parent; spacing: 1
        Image {
            Layout.topMargin: 10; Layout.alignment: Qt.AlignHCenter | Qt.AlignTop
            width: 48; height: 48;
            source: "file:/" + Branding.imagePath(Branding.ProductLogo);
            fillMode: Image.PreserveAspectFit
        }
        Item { Layout.fillHeight: true; }
        Rectangle {
            id: nextArea
            Layout.preferredHeight: 64; Layout.fillWidth: true
            color: mouseNext.containsMouse ? "#3daee9" : "transparent";
            visible: ViewManager.backAndNextVisible;
            MouseArea {
                id: mouseNext; anchors.fill: parent; hoverEnabled: true
                onClicked: { ViewManager.next(); }
                Text { anchors.centerIn: parent; text: "Next"; color: "white" }
            }
        }
    }
}
EOF

cat > /usr/share/calamares/branding/apex/sidebar.qml << 'EOF'
import io.calamares.ui 1.0
import io.calamares.core 1.0
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: sideBar;
    color: Branding.styleString( Branding.SidebarBackground );
    height: 48; width: parent.width

    RowLayout {
        anchors.fill: parent; spacing: 2;
        Repeater {
            model: ViewManager
            Rectangle {
                Layout.fillWidth: true; height: 48;
                color: index == ViewManager.currentStepIndex ? "#31363b" : "transparent";
                Text {
                    anchors.centerIn: parent
                    text: display;
                    color: index == ViewManager.currentStepIndex ? "#3daee9" : "#eff0f1";
                }
            }
        }
    }
}
EOF

# E. SETTINGS.CONF (Standardized)
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

# F. DESKTOP SHORTCUT & ICONS
mkdir -p /home/liveuser/.config/autostart
cat > /home/liveuser/.config/autostart/calamares.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=Install Apex Linux
GenericName=Live Installer
Exec=sudo -E calamares
Icon=/usr/share/calamares/branding/apex/icon.png
Terminal=false
StartupNotify=true
Categories=System;Qt;
EOF

mkdir -p /home/liveuser/Desktop
cp /home/liveuser/.config/autostart/calamares.desktop /home/liveuser/Desktop/install-apex.desktop
chmod +x /home/liveuser/Desktop/install-apex.desktop
chown -R liveuser:liveuser /home/liveuser

# System Icons (Replacements)
cp /usr/share/calamares/branding/apex/icon.png /usr/share/pixmaps/fedora-logo-sprite.png
cp /usr/share/calamares/branding/apex/icon.png /usr/share/pixmaps/fedora-logo.png 2>/dev/null || true

echo ">>> APEX BRANDING COMPLETE <<<"
%end
