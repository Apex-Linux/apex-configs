# === APEX LINUX BRANDING ===
%packages
calamares
qt6-qtsvg
git
fastfetch
# plymouth-plugin-script is needed for custom theme
plymouth-plugin-script
findutils
sed
# ImageMagick for resizing icons if needed
ImageMagick
%end

# === STEP 1: ASSET INJECTION (With DNS Fix) ===
%post --erroronfail
set -e
echo ">>> [CHROOT] STARTING ASSET INJECTION <<<"

# 1. FIX DNS (The "Blindness" Fix)
rm -f /etc/resolv.conf
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 1.1.1.1" >> /etc/resolv.conf

# 2. CLONE REPO (With Verbose Debugging)
echo ">>> Cloning Apex Configs..."
rm -rf /tmp/apex-assets
if ! git clone --depth 1 --verbose https://github.com/Apex-Linux/apex-configs.git /tmp/apex-assets; then
    echo "❌ [ERROR] Git Clone Failed!"
    exit 1
fi

# 3. VERIFY DOWNLOAD
if [ ! -f /tmp/apex-assets/iso/branding/logo.txt ]; then
    echo "❌ [ERROR] Files missing after clone!"
    ls -R /tmp/apex-assets
    exit 1
fi
echo "✅ Repo cloned successfully."

# 4. INSTALL ASSETS
mkdir -p /usr/share/apex-linux/
mkdir -p /usr/share/calamares/branding/apex/
echo ">>> Installing Logo & Calamares Assets..."
cp -f /tmp/apex-assets/iso/branding/calamares/* /usr/share/calamares/branding/apex/
cp -f /tmp/apex-assets/iso/branding/logo.txt /usr/share/apex-linux/logo.txt

# 5. CLEANUP
rm -rf /tmp/apex-assets
rm -f /etc/resolv.conf
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

# === STEP 3: CUSTOM PLYMOUTH THEME (Boot Splash Fix) ===
%post --erroronfail
set -e
echo ">>> [CHROOT] CREATING APEX PLYMOUTH THEME <<<"

THEME_DIR="/usr/share/plymouth/themes/apex"
mkdir -p "$THEME_DIR"

# 1. Copy Logo & Get a Spinner
cp /usr/share/calamares/branding/apex/squid.png "$THEME_DIR/watermark.png"
# If a spinner doesn't exist, create a dummy one to prevent errors
if [ -f /usr/share/plymouth/themes/spinner/throbber-00.png ]; then
    cp /usr/share/plymouth/themes/spinner/throbber-*.png "$THEME_DIR/"
else
    touch "$THEME_DIR/throbber-00.png"
fi

# 2. Create the Theme File (.plymouth)
cat > "$THEME_DIR/apex.plymouth" << 'EOF'
[Plymouth Theme]
Name=Apex Linux
Description=A theme for Apex Linux featuring a logo and spinner.
ModuleName=script

[script]
ImageDir=/usr/share/plymouth/themes/apex
ScriptFile=/usr/share/plymouth/themes/apex/apex.script
EOF

# 3. Create the Script File (.script)
# This script centers the logo and places a spinner below it.
cat > "$THEME_DIR/apex.script" << 'EOF'
# Load images
logo_image = Image("watermark.png");
spinner_image = Image("throbber-00.png");

# Get screen dimensions
screen_width = Window.GetWidth();
screen_height = Window.GetHeight();

# Calculate positions to center the logo
logo_x = (screen_width / 2) - (logo_image.GetWidth() / 2);
logo_y = (screen_height / 2) - (logo_image.GetHeight() / 2) - 50; # Move up slightly

# Create and position the logo sprite
logo_sprite = Sprite(logo_image);
logo_sprite.SetPosition(logo_x, logo_y, 100);

# Calculate positions for the spinner (below logo)
spinner_x = (screen_width / 2) - (spinner_image.GetWidth() / 2);
spinner_y = logo_y + logo_image.GetHeight() + 20;

# Create and position the spinner sprite
spinner_sprite = Sprite(spinner_image);
spinner_sprite.SetPosition(spinner_x, spinner_y, 100);

# Function to handle boot progress (optional, for smootherspinner)
fun progress_callback (duration, progress) {
  # We could animate the spinner here, but a static one is fine for now.
}
Plymouth.SetBootProgressFunction(progress_callback);

# Function to handle quitting
fun quit_callback () {
  logo_sprite.SetOpacity(0);
  spinner_sprite.SetOpacity(0);
}
Plymouth.SetQuitFunction(quit_callback);
EOF

# 4. ACTIVATE THE THEME
# This is the critical part. We set the default and rebuild the initramfs.
echo ">>> Setting Apex theme as default..."
plymouth-set-default-theme apex

echo ">>> Rebuilding initramfs (this may take a minute)..."
dracut --force --verbose

echo ">>> [CHROOT] PLYMOUTH THEME INSTALLED & ACTIVATED <<<"
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

# === STEP 6: CALAMARES CONFIGURATION (UI Polish) ===
%post --erroronfail
set -e
echo ">>> [CHROOT] CONFIGURING CALAMARES <<<"

rm -rf /usr/share/calamares/branding/fedora
rm -rf /usr/share/calamares/branding/default

# A. Branding Description (Colors & Text Fixed)
# We use lighter text colors for better contrast on the dark sidebar.
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
   sidebarTextSelect:    "#FFFFFF"
   sidebarTextHighlight: "#4FD1C5"
EOF

# B. Sidebar QML (Icon Size Fixed)
# We use preserveAspectFit and explicit dimensions to fix the messy icon.
cat > /usr/share/calamares/branding/apex/sidebar.qml << 'EOF'
import QtQuick 2.0
import calamares.branding 1.0

Rectangle {
    id: sidebar
    width: 200
    height: 520
    color: Branding.styleString(Branding.SidebarBackground)

    Column {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 20

        // Fixed Logo Image
        Image {
            id: logo
            source: Branding.image(Branding.ProductLogo)
            width: 180
            height: 180
            anchors.horizontalCenter: parent.horizontalCenter
            fillMode: Image.PreserveAspectFit
            smooth: true
        }

        // Navigation Steps
        Repeater {
            model: Branding.viewSteps
            delegate: Text {
                text: model.display
                color: model.current ? Branding.styleString(Branding.SidebarTextSelect) : Branding.styleString(Branding.SidebarText)
                font.pixelSize: 16
                font.bold: model.current
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }
}
EOF

# C. Slideshow QML (Background Fixed)
# We added a dark Rectangle behind the text to fix the "white screen" issue.
cat > /usr/share/calamares/branding/apex/show.qml << 'EOF'
import QtQuick 2.0
import calamares.slideshow 1.0

Presentation {
    id: presentation
    Timer {
        interval: 5000; running: true; repeat: true
        onTriggered: presentation.goToNextSlide()
    }
    
    // Add a background rectangle
    Rectangle {
        anchors.fill: parent
        color: "#1A202C" // A dark background color
    }

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
    Slide {
        anchors.fill: parent
        Text {
            anchors.centerIn: parent
            text: "Powered by KDE Plasma<br/><br/>A powerful and flexible desktop."
            color: "white"
            font.pixelSize: 24
            horizontalAlignment: Text.AlignCenter
        }
    }
}
EOF

# D. Other Calamares Configs (Unchanged)
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
