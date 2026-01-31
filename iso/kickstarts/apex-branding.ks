# === APEX LINUX BRANDING ===
# Handles Logos, ASCII Art, Icons, and Calamares UI Injection.

%packages
calamares
%end

%post
# --- 1. DOWNLOAD ASSETS ---
mkdir -p /usr/share/apex-linux

# A. ASCII Art
wget https://raw.githubusercontent.com/Apex-Linux/apex-configs/main/iso/branding/logo.txt -O /usr/share/apex-linux/logo.txt

# B. Main Logo/Icon (Square "A" Logo) -> squid.png
wget https://raw.githubusercontent.com/Apex-Linux/apex-configs/main/iso/branding/calamares/squid.png -O /usr/share/apex-linux/squid.png

# C. Welcome Banner (Rectangular Text Logo) -> welcome.png
wget https://raw.githubusercontent.com/Apex-Linux/apex-configs/main/iso/branding/calamares/welcome.png -O /usr/share/apex-linux/welcome.png

# --- 2. UNIVERSAL SHELL BRANDING ---

# A. BASH & ZSH
cat > /etc/profile.d/apex-branding.sh << 'EOF'
alias fastfetch='fastfetch --logo /usr/share/apex-linux/logo.txt --logo-type file --logo-color-1 blue'
alias neofetch='neofetch --source /usr/share/apex-linux/logo.txt --ascii_distro "Apex Linux"'
alias screenfetch='screenfetch -A "Apex Linux" -D "Apex Linux"'
EOF
chmod +x /etc/profile.d/apex-branding.sh

# B. FISH SHELL
mkdir -p /etc/fish/conf.d
cat > /etc/fish/conf.d/apex-branding.fish << 'EOF'
function fastfetch
    command fastfetch --logo /usr/share/apex-linux/logo.txt --logo-type file --logo-color-1 blue $argv
end
function neofetch
    command neofetch --source /usr/share/apex-linux/logo.txt --ascii_distro "Apex Linux" $argv
end
EOF

# --- 3. CALAMARES BRANDING ---

# A. Delete Fedora Defaults
rm -rf /usr/share/calamares/branding/fedora
rm -rf /usr/share/calamares/branding/default
rm -rf /usr/share/calamares/branding/fedoraproject

# B. Create Apex Branding Directory
mkdir -p /usr/share/calamares/branding/apex

# C. Place Images Correctly
# "squid.png" is the Logo/Icon
cp /usr/share/apex-linux/squid.png /usr/share/calamares/branding/apex/squid.png
# "welcome.png" is the Side Banner
cp /usr/share/apex-linux/welcome.png /usr/share/calamares/branding/apex/welcome.png

# D. branding.desc (Mapped Correctly)
cat > /usr/share/calamares/branding/apex/branding.desc << 'EOF'
---
componentName:  apex
welcomeStyleCalamares:   false
welcomeExpandingLogo:   true
windowExpanding:    normal
windowSize: 920px,630px
windowPlacement: center
sidebar: qml,bottom
navigation: qml,right

strings:
    productName:         Apex Linux
    shortProductName:    Apex
    version:             2026.1
    shortVersion:        2026
    versionedName:       Apex Linux 2026.1
    shortVersionedName:  Apex 2026
    bootloaderEntryName: Apex
    productUrl:          https://github.com/Apex-Linux
    supportUrl:          https://github.com/Apex-Linux
    knownIssuesUrl:      https://github.com/Apex-Linux
    releaseNotesUrl:     https://github.com/Apex-Linux
    donateUrl:           https://github.com/Apex-Linux

images:
    productLogo:         "squid.png"
    productIcon:         "squid.png"
    productWelcome:      "welcome.png"

slideshow:               "show.qml"
slideshowAPI:            1

style:
   SidebarBackground:    "#232629"
   SidebarText:          "#eff0f1"
   SidebarTextCurrent:   "#3daee9"
   SidebarBackgroundCurrent: "#31363b"
EOF

# E. show.qml (Slideshow)
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
    Slide {
        anchors.fill: parent
        Text {
            anchors.centerIn: parent
            text: "Clean. Fast. Apex.<br/><br/>We are setting up your system now."
            color: "white"
            font.pixelSize: 24
            horizontalAlignment: Text.AlignCenter
        }
    }
}
EOF

# F. navigation.qml (Right Bar)
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
            # Uses productLogo from branding.desc (squid.png)
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

# G. sidebar.qml (Bottom Bar)
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

# --- 4. APPLY SETTINGS ---
sed -i 's/branding: default/branding: apex/' /etc/calamares/settings.conf
sed -i 's/branding: fedora/branding: apex/' /etc/calamares/settings.conf

# Autostart
mkdir -p /home/liveuser/.config/autostart
cat > /home/liveuser/.config/autostart/calamares.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=Install Apex Linux
GenericName=Live Installer
Exec=sudo -E calamares
Icon=/usr/share/apex-linux/squid.png
Terminal=false
StartupNotify=true
Categories=System;Qt;
EOF

# Shortcut on Desktop
mkdir -p /home/liveuser/Desktop
cp /home/liveuser/.config/autostart/calamares.desktop /home/liveuser/Desktop/install-apex.desktop
chmod +x /home/liveuser/Desktop/install-apex.desktop
chown -R liveuser:liveuser /home/liveuser

# --- 5. SYSTEM ICON OVERWRITE (GLOBAL) ---
# We overwrite Fedora icons with squid.png (the square App Icon)
cp /usr/share/apex-linux/squid.png /usr/share/pixmaps/fedora-logo-sprite.png
cp /usr/share/apex-linux/squid.png /usr/share/pixmaps/fedora-logo.png 2>/dev/null || true
cp /usr/share/apex-linux/squid.png /usr/share/icons/hicolor/48x48/apps/fedora-logo-icon.png 2>/dev/null || true
cp /usr/share/apex-linux/squid.png /usr/share/icons/hicolor/scalable/apps/fedora-logo-icon.svg 2>/dev/null || true
cp /usr/share/apex-linux/squid.png /usr/share/icons/hicolor/scalable/apps/start-here.svg 2>/dev/null || true
cp /usr/share/apex-linux/squid.png /usr/share/icons/hicolor/scalable/places/start-here.svg 2>/dev/null || true
gtk-update-icon-cache /usr/share/icons/hicolor/
%end
