# === APEX LINUX BRANDING ===
# Handles Logos, ASCII Art, Icons, and Calamares UI Injection.

%packages
calamares
qt6-qtsvg
%end

# === CRITICAL STEP: COPY FILES FROM GITHUB WORKSPACE ===
%post --nochroot --erroronfail
echo ">>> COPYING BRANDING ASSETS FROM GITHUB WORKSPACE <<<"

# Create destination inside the ISO root
mkdir -p $INSTALL_ROOT/usr/share/apex-linux/

# Copy the branding folder from the GitHub Runner path
cp -r /__w/apex-configs/apex-configs/iso/branding/* $INSTALL_ROOT/usr/share/apex-linux/

echo ">>> COPY COMPLETE <<<"
%end

# === REGULAR SETUP (INSIDE THE ISO) ===
%post --erroronfail

echo ">>> CONFIGURING APEX BRANDING <<<"

# FIX PERMISSIONS (Since we copied them from outside)
chmod -R 755 /usr/share/apex-linux

# --- 1. UNIVERSAL SHELL BRANDING ---
cat >> /etc/bashrc << 'EOF'
alias fastfetch='fastfetch --logo /usr/share/apex-linux/logo.txt --logo-type file --logo-color-1 blue'
alias neofetch='neofetch --source /usr/share/apex-linux/logo.txt --ascii_distro "Apex Linux"'
alias screenfetch='screenfetch -A "Apex Linux" -D "Apex Linux"'
EOF

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

# B. Create Apex Branding
mkdir -p /usr/share/calamares/branding/apex

# C. MOVE IMAGES & CONFIG
cp /usr/share/apex-linux/calamares/squid.png /usr/share/calamares/branding/apex/squid.png
cp /usr/share/apex-linux/calamares/welcome.png /usr/share/calamares/branding/apex/welcome.png

# Copy the branding.desc you provided (It was copied in the folder above)
cp /usr/share/apex-linux/calamares/branding.desc /usr/share/calamares/branding/apex/branding.desc

# D. GENERATE QML FILES (If they aren't in the repo, we generate them safely here)
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

# --- 4. DESKTOP SHORTCUT & ICONS ---
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

# --- 5. OVERWRITE SYSTEM ICONS (GLOBAL) ---
cp /usr/share/apex-linux/calamares/squid.png /usr/share/pixmaps/fedora-logo-sprite.png
cp /usr/share/apex-linux/calamares/squid.png /usr/share/pixmaps/fedora-logo.png 2>/dev/null || true
cp /usr/share/apex-linux/calamares/squid.png /usr/share/icons/hicolor/48x48/apps/fedora-logo-icon.png 2>/dev/null || true
cp /usr/share/apex-linux/calamares/squid.png /usr/share/icons/hicolor/scalable/apps/fedora-logo-icon.svg 2>/dev/null || true
cp /usr/share/apex-linux/calamares/squid.png /usr/share/icons/hicolor/scalable/apps/start-here.svg 2>/dev/null || true
cp /usr/share/apex-linux/calamares/squid.png /usr/share/icons/hicolor/scalable/places/start-here.svg 2>/dev/null || true
gtk-update-icon-cache /usr/share/icons/hicolor/

echo ">>> APEX BRANDING COMPLETE <<<"
%end
