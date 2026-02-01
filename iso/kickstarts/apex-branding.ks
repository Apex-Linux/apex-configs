# === APEX LINUX BRANDING ===
# Handles Logos, ASCII Art, Icons, and Calamares UI Injection.

%packages
calamares
qt6-qtsvg
%end

# === STEP 1: COPY ASSETS FROM GITHUB ===
%post --nochroot --erroronfail
echo ">>> COPYING BRANDING ASSETS FROM GITHUB WORKSPACE <<<"
mkdir -p $INSTALL_ROOT/usr/share/apex-linux/
# Copy all assets (images/logos) from the repo
cp -r /__w/apex-configs/apex-configs/iso/branding/* $INSTALL_ROOT/usr/share/apex-linux/
echo ">>> COPY COMPLETE <<<"
%end

# === STEP 2: CONFIGURE SYSTEM ===
%post --erroronfail

echo ">>> CONFIGURING APEX BRANDING <<<"
chmod -R 755 /usr/share/apex-linux

# --- 1. UNIVERSAL SHELL BRANDING ---
# We use z99-apex.sh to ensure this runs LAST and overrides Fedora
cat > /etc/profile.d/z99-apex.sh << 'EOF'
alias fastfetch='fastfetch --logo /usr/share/apex-linux/logo.txt --logo-type file --logo-color-1 blue'
alias neofetch='neofetch --source /usr/share/apex-linux/logo.txt --ascii_distro "Apex Linux"'
EOF
chmod +x /etc/profile.d/z99-apex.sh

mkdir -p /etc/fish/conf.d
cat > /etc/fish/conf.d/apex-branding.fish << 'EOF'
function fastfetch
    command fastfetch --logo /usr/share/apex-linux/logo.txt --logo-type file --logo-color-1 blue $argv
end
function neofetch
    command neofetch --source /usr/share/apex-linux/logo.txt --ascii_distro "Apex Linux" $argv
end
EOF

# --- 2. CALAMARES BRANDING SETUP ---

# A. Delete Defaults
rm -rf /usr/share/calamares/branding/fedora
rm -rf /usr/share/calamares/branding/default
rm -rf /usr/share/calamares/branding/fedoraproject

# B. Create Apex Branding Directory
mkdir -p /usr/share/calamares/branding/apex

# C. COPY IMAGES
# We use 'squid.png' here because your branding.desc asks for 'squid.png'
cp /usr/share/apex-linux/calamares/squid.png /usr/share/calamares/branding/apex/squid.png
cp /usr/share/apex-linux/calamares/welcome.png /usr/share/calamares/branding/apex/welcome.png

# D. GENERATE BRANDING.DESC (CRITICAL FIX)
# We WRITE this file here to ensure it exists. No more missing file errors.
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
slideshowAPI:            1

style:
   sidebarBackground:    "#292f34"
   sidebarText:          "#FFFFFF"
   sidebarTextSelect:    "#292f34"
   sidebarTextHighlight: "#00BFFF"
EOF

# E. GENERATE QML FILES
cat > /usr/share/calamares/branding/apex/show.qml << 'EOF'
import QtQuick 2.0;
import calamares.slideshow 1.0;

Presentation
{
    id: presentation
    Timer {
        interval: 5000
        running: true
        repeat: true
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
import QtQuick 2.3
import QtQuick.Controls 2.10
import QtQuick.Layouts 1.3

Rectangle {
    id: navigationBar;
    color: Branding.styleString( Branding.SidebarBackground );
    height: parent.height;
    width:64;

    ColumnLayout {
        anchors.fill: parent;
        spacing: 1

        Image {
            Layout.topMargin: 10;
            Layout.alignment: Qt.AlignHCenter | Qt.AlignTop
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
import QtQuick 2.3
import QtQuick.Layouts 1.3

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

# --- 3. OVERWRITE SETTINGS.CONF ---
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

# --- 4. DESKTOP SHORTCUT ---
mkdir -p /home/liveuser/.config/autostart
cat > /home/liveuser/.config/autostart/calamares.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=Install Apex Linux
GenericName=Live Installer
Exec=sudo -E calamares
Icon=/usr/share/apex-linux/calamares/squid.png
Terminal=false
StartupNotify=true
Categories=System;Qt;
EOF

mkdir -p /home/liveuser/Desktop
cp /home/liveuser/.config/autostart/calamares.desktop /home/liveuser/Desktop/install-apex.desktop
chmod +x /home/liveuser/Desktop/install-apex.desktop
chown -R liveuser:liveuser /home/liveuser

# --- 5. SYSTEM ICONS ---
cp /usr/share/apex-linux/calamares/squid.png /usr/share/pixmaps/fedora-logo-sprite.png
cp /usr/share/apex-linux/calamares/squid.png /usr/share/pixmaps/fedora-logo.png 2>/dev/null || true
cp /usr/share/apex-linux/calamares/squid.png /usr/share/icons/hicolor/48x48/apps/fedora-logo-icon.png 2>/dev/null || true
cp /usr/share/apex-linux/calamares/squid.png /usr/share/icons/hicolor/scalable/apps/fedora-logo-icon.svg 2>/dev/null || true
cp /usr/share/apex-linux/calamares/squid.png /usr/share/icons/hicolor/scalable/apps/start-here.svg 2>/dev/null || true
cp /usr/share/apex-linux/calamares/squid.png /usr/share/icons/hicolor/scalable/places/start-here.svg 2>/dev/null || true
gtk-update-icon-cache /usr/share/icons/hicolor/

echo ">>> APEX BRANDING COMPLETE <<<"
%end
