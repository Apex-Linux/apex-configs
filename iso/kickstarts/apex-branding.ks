# === APEX LINUX BRANDING (Summit Edition - Genesis 1.0) ===
# Features: Native Apps, Performance Selector, Full DE Selection, Custom Installer Background.

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
papirus-icon-theme
potrace
# Remove bloat from Live ISO
-libsForQt5.discover
-plasma-discover
-plasma-discover-notifier
%end

# === STEP 1: ASSET INJECTION & REPO SETUP ===
%post --erroronfail
set -e
echo ">>> [CHROOT] STARTING ASSET INJECTION <<<"
rm -f /etc/resolv.conf
echo "nameserver 8.8.8.8" > /etc/resolv.conf

# 1. APEX CORE REPO
cat > /etc/yum.repos.d/apex-core.repo << 'EOF'
[apex-core]
name=Apex Core
baseurl=https://download.copr.fedorainfracloud.org/results/ackerman/apex-core/fedora-$releasever-$basearch/
enabled=1
gpgcheck=0
priority=90
EOF

# 2. Get Visual Assets (Cursors/Grub)
rm -rf /tmp/apex-assets
mkdir -p /tmp/apex-assets
wget -O /tmp/apex-assets/Bibata.tar.xz https://github.com/ful1e5/Bibata_Cursor/releases/download/v2.0.7/Bibata-Modern-Ice.tar.xz
wget -O /tmp/apex-assets/grub-theme.tar.gz https://github.com/vinceliuice/grub2-themes/raw/master/grub2-themes-vimix.tar.gz

# 3. Branding Files (Config Repo)
if ! git clone --depth 1 --verbose https://github.com/Apex-Linux/apex-configs.git /tmp/apex-git; then
    echo "❌ Git Clone Failed (Configs)!"
else
    # Calamares Branding
    mkdir -p /usr/share/calamares/branding/apex/
    cp -f /tmp/apex-git/iso/branding/calamares/* /usr/share/calamares/branding/apex/
    
    # SYSTEM LOGO (Default Branding)
    mkdir -p /usr/share/apex-linux/
    [ -f /tmp/apex-git/iso/branding/logo.png ] && cp /tmp/apex-git/iso/branding/logo.png /usr/share/apex-linux/logo.png
fi

# 4. INSTALLER BACKGROUND (Core Tools Repo)
# We need apexlogo07.png from apex-core-tools/apex-core/apex-backgrounds/src/
if ! git clone --depth 1 --verbose https://github.com/Apex-Linux/apex-core-tools.git /tmp/apex-tools; then
    echo "❌ Git Clone Failed (Core Tools)!"
else
    echo ">>> Installing Installer Background..."
    BG_SRC="/tmp/apex-tools/apex-core/apex-backgrounds/src/apexlogo07.png"
    BG_DEST="/usr/share/calamares/branding/apex/install_bg.png"
    
    if [ -f "$BG_SRC" ]; then
        cp "$BG_SRC" "$BG_DEST"
    else
        echo "⚠️ Warning: apexlogo07.png not found at $BG_SRC"
        # Fallback to creating a placeholder or using logo if missing to prevent crash
        cp /usr/share/apex-linux/logo.png "$BG_DEST" 
    fi
fi

# Install Cursors & Grub Theme
tar -xf /tmp/apex-assets/Bibata.tar.xz -C /usr/share/icons/
mkdir -p /usr/share/grub/themes/apex
tar -xf /tmp/apex-assets/grub-theme.tar.gz -C /usr/share/grub/themes/apex --strip-components=1

rm -rf /tmp/apex-assets
rm -rf /tmp/apex-git
rm -rf /tmp/apex-tools
%end

# === STEP 2: THEME ENFORCER ===
%post --erroronfail
set -e
mkdir -p /usr/share/icons/default
echo "[Icon Theme]" > /usr/share/icons/default/index.theme
echo "Inherits=Bibata-Modern-Ice" >> /usr/share/icons/default/index.theme

mkdir -p /etc/gtk-3.0
cat > /etc/gtk-3.0/settings.ini << 'EOF'
[Settings]
gtk-icon-theme-name=Papirus-Dark
gtk-cursor-theme-name=Bibata-Modern-Ice
gtk-theme-name=Adwaita-dark
gtk-application-prefer-dark-theme=1
EOF

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
%end

# === STEP 3: IDENTITY SURGERY ===
%post --erroronfail
set -e
sed -i 's/^NAME=.*$/NAME="Apex Linux"/' /etc/os-release
sed -i 's/^ID=.*$/ID=apex/' /etc/os-release
sed -i 's/^PRETTY_NAME=.*$/PRETTY_NAME="Apex Linux 1.0 (Genesis)"/' /etc/os-release
sed -i 's/^ID_LIKE=.*$/ID_LIKE="fedora"/' /etc/os-release
sed -i 's/^HOME_URL=.*$/HOME_URL="https:\/\/apexlinux.org"/' /etc/os-release
echo -e "Apex Linux 1.0 (Genesis) \n \l" > /etc/issue
%end

# === STEP 4: PLYMOUTH THEME ===
%post --erroronfail
set -e
THEME_DIR="/usr/share/plymouth/themes/apex"
SQUID_ICON="/usr/share/calamares/branding/apex/squid.png"
mkdir -p "$THEME_DIR"
if command -v magick >/dev/null 2>&1; then
    magick "$SQUID_ICON" -resize 150x150 "$THEME_DIR/watermark.png"
    magick "$SQUID_ICON" -resize 48x48 "$THEME_DIR/throbber-00.png"
else
    cp "$SQUID_ICON" "$THEME_DIR/watermark.png"
    cp "$SQUID_ICON" "$THEME_DIR/throbber-00.png"
fi
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
spinner_image = Image("throbber-00.png");
screen_width = Window.GetWidth();
screen_height = Window.GetHeight();
center_x = screen_width / 2;
center_y = screen_height / 2;
logo_sprite = Sprite(logo_image);
logo_sprite.SetX(center_x - logo_image.GetWidth() / 2);
logo_sprite.SetY(center_y - logo_image.GetHeight() / 2 - 50);
logo_sprite.SetZ(10);
spinner_sprite = Sprite(spinner_image);
spinner_sprite.SetX(center_x - spinner_image.GetWidth() / 2);
spinner_sprite.SetY(center_y + 60);
spinner_sprite.SetZ(20);
angle = 0;
fun refresh_callback () {
    angle += 0.15;
    spinner_sprite.SetImage(spinner_image.Rotate(angle));
}
Plymouth.SetRefreshFunction (refresh_callback);
EOF
plymouth-set-default-theme apex
KVER=$(ls /lib/modules | sort -V | tail -n 1)
dracut --force --kver "$KVER"
%end

# === STEP 5: CONFIG GENERATION ===
%post --erroronfail
set -e
mkdir -p /etc/calamares/modules

# --- 1. HARDWARE SCRIPT ---
cat > /usr/bin/apex-hw-detect << 'SCRIPT'
#!/bin/bash
echo ">>> [APEX] Starting Hardware Optimization..."
dnf install -y https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
dnf config-manager --enable rpmfusion-nonfree-nvidia-driver

# GPU
if lspci -k | grep -A 2 -E "(VGA|3D)" | grep -i "nvidia"; then
    if lspci | grep -E "GeForce (GTX |GT |)(6[0-9][0-9]|7[0-9][0-9])"; then
        dnf install -y akmod-nvidia-470xx xorg-x11-drv-nvidia-470xx-cuda
    else
        dnf install -y akmod-nvidia xorg-x11-drv-nvidia-cuda
        [ -d "/sys/class/power_supply/BAT0" ] && dnf install -y nvidia-powerd && systemctl enable nvidia-powerd
    fi
fi
if lspci -k | grep -A 2 -E "(VGA|3D)" | grep -i "amd"; then
    dnf install -y mesa-va-drivers-freeworld mesa-vdpau-drivers-freeworld
    dnf swap -y mesa-va-drivers mesa-va-drivers-freeworld
fi
if lspci -k | grep -A 2 -E "(VGA|3D)" | grep -i "intel"; then
    dnf install -y intel-media-driver libva-intel-driver
fi

# MULTIMEDIA
dnf swap -y ffmpeg-free ffmpeg --allowerasing
dnf groupupdate -y multimedia --setopt="install_weak_deps=False" --exclude=PackageKit-gstreamer-plugin
dnf install -y gstreamer1-plugin-openh264 mozilla-openh264

# GNOME POLISH
if rpm -q gnome-shell; then
    cat > /usr/share/glib-2.0/schemas/99-apex-gnome.gschema.override << 'EOF'
[org.gnome.shell]
enabled-extensions=['dash-to-dock@micxgx.gmail.com', 'ding@rastersoft.com', 'appindicatorsupport@rgcjonas.gmail.com']
favorite-apps=['org.gnome.Nautilus.desktop', 'org.gnome.Terminal.desktop', 'zen-browser.desktop', 'org.gnome.Loupe.desktop', 'org.gnome.Extensions.desktop', 'org.gnome.Tweaks.desktop']
[org.gnome.desktop.interface]
color-scheme='prefer-dark'
gtk-theme='Adwaita-dark'
icon-theme='Papirus-Dark'
[org.gnome.desktop.background]
picture-uri='file:///usr/share/backgrounds/apex/apex-default.jpg'
picture-uri-dark='file:///usr/share/backgrounds/apex/apex-default.jpg'
EOF
    glib-compile-schemas /usr/share/glib-2.0/schemas/
fi
SCRIPT
chmod +x /usr/bin/apex-hw-detect

# --- 2. BOOTLOADER SWITCHER ---
cat > /usr/bin/apex-bootloader-setup << 'SCRIPT'
#!/bin/bash
echo ">>> [APEX] Bootloader Configuration..."
if rpm -q refind; then
    refind-install
fi
if rpm -q systemd-boot && [ ! -d "/sys/firmware/efi" ]; then
    echo ">>> [APEX] Systemd-boot requested but Legacy BIOS detected. Skipping."
elif rpm -q systemd-boot; then
    bootctl install
    kernel-install add $(uname -r) /boot/vmlinuz-$(uname -r)
fi
grub2-mkconfig -o /boot/grub2/grub.cfg
SCRIPT
chmod +x /usr/bin/apex-bootloader-setup

# --- 3. DM ENFORCER ---
cat > /usr/bin/apex-dm-enforce << 'SCRIPT'
#!/bin/bash
echo ">>> [APEX] Enforcing Display Manager..."
systemctl disable gdm sddm lightdm ly greetd cosmic-greeter || true
if rpm -q cosmic-greeter; then systemctl enable cosmic-greeter
elif rpm -q ly; then systemctl enable ly
elif rpm -q greetd; then systemctl enable greetd
elif rpm -q sddm; then systemctl enable sddm
elif rpm -q gdm; then systemctl enable gdm
elif rpm -q lightdm; then systemctl enable lightdm
fi
systemctl set-default graphical.target
SCRIPT
chmod +x /usr/bin/apex-dm-enforce


# --- CALAMARES CONFIGS ---
cat > /etc/calamares/modules/netinstall-desktop.conf << 'EOF'
groupsUrl: file:///etc/calamares/modules/netinstall-desktop.yaml
required: true
label:
    sidebar: "Desktop"
    title: "Select Desktop"
EOF

# YAML 1: DESKTOP
cat > /etc/calamares/modules/netinstall-desktop.yaml << 'EOF'
- name: "Apex Core"
  description: "Identity, Drivers, and Tools (Required)"
  hidden: true
  selected: true
  critical: true
  packages:
    - linux-firmware
    - microcode_ctl
    - amd-ucode-firmware
    - grub2-efi-x64
    - shim-x64
    - efibootmgr
    - NetworkManager-wifi
    - bluez
    - wpa_supplicant
    - apex-release          # Identity
    - apex-backgrounds      # Visuals
    - apex-updater          # Native Updater
    - terra-release
    - pciutils
    - fwupd
    - irqbalance

- name: "System Performance"
  description: "Select your kernel optimization strategy."
  expanded: true
  groups:
    - name: "Standard RPM (Default)"
      description: "Standard Fedora kernel configuration.\nBest for stability and general use."
      selected: true
      packages: [] 

    - name: "Apex Gaming (Tuned)"
      description: "Optimized for High FPS & Low Latency.\n\nIncludes:\n- SCX LAVD Scheduler (CachyOS Tech)\n- Google BBR Networking\n- Aggressive I/O Tuning"
      packages:
        - apex-tuning          # The Brain
        - apex-schedulers      # The Turbo
        - gamemode

- name: "Kernel"
  expanded: true
  groups:
    - name: "Linux Kernel (Stable)"
      description: "Latest stable release."
      selected: true
      packages: [ kernel, kernel-modules, kernel-modules-extra ]

- name: "Bootloader Choice"
  expanded: true
  groups:
    - name: "GRUB2 (Default)"
      selected: true
      packages: [ grub2-tools, grub2-tools-extra ]
    - name: "rEFInd (Visual)"
      packages: [ refind ]
    - name: "Systemd-boot (Minimal)"
      packages: [ systemd-boot ]

- name: "Desktop Environment"
  expanded: true
  groups:
  
    # --- MINIMAL ---
    - name: "NO DESKTOP"
      description: "Console Only. Minimal Install."
      packages: [ @core ]
    
    # --- FLAGSHIP EXPERIENCES ---
    - name: "GNOME (Apex Riced)"
      description: "Flagship Experience. Polished & Modern."
      selected: true
      packages:
        - gnome-shell
        - nautilus
        - gnome-terminal
        - gnome-control-center
        - gnome-tweaks
        - gnome-extensions-app
        - gnome-shell-extension-dash-to-dock
        - gnome-shell-extension-desktop-icons
        - gnome-shell-extension-appindicator
        - loupe
        - xdg-desktop-portal-gnome

    - name: "KDE Plasma (Apex Riced)"
      packages:
        - plasma-desktop
        - plasma-workspace
        - konsole
        - dolphin
        - ark
        - haruna
        - gwenview
        - xdg-desktop-portal-kde

    - name: "Niri (Noctalia Shell)"
      description: "Tiling WM with Noctalia Shell."
      packages: [ apex-niri-configs ]

    - name: "MangoWC (Noctalia Shell)"
      description: "Compositor with Noctalia Shell."
      packages: [ apex-mangowc-configs ]

    # --- VANILLA EXPERIENCES ---
    - name: "GNOME (Vanilla)"
      packages: [ gnome-shell, nautilus, gnome-terminal, gnome-control-center, xdg-desktop-portal-gnome ]

    - name: "KDE Plasma (Vanilla)"
      packages: [ plasma-desktop, plasma-workspace, konsole, dolphin, xdg-desktop-portal-kde ]

    # --- COMMUNITY / OTHER DESKTOPS ---
    - name: "COSMIC (Alpha)"
      packages:
        - cosmic-session
        - cosmic-comp

    - name: "Budgie"
      packages:
        - @budgie-desktop

    - name: "Cinnamon"
      packages:
        - @cinnamon-desktop

    - name: "XFCE"
      packages:
        - @xfce-desktop-environment

    - name: "MATE"
      packages:
        - @mate-desktop-environment

    - name: "LXQt"
      packages:
        - @lxqt-desktop-environment

    - name: "Sway"
      packages:
        - sway
        - swaybg
        - swayidle
        - swaylock
        - waybar
        - foot
        - fuzzel

    - name: "i3"
      packages:
        - i3
        - i3status
        - i3lock
        - dmenu
        - dunst
        
EOF

# YAML 2: DISPLAY MANAGER
cat > /etc/calamares/modules/netinstall-dm.yaml << 'EOF'
- name: "Display Manager"
  description: "Select your Login Screen."
  expanded: true
  groups:
    - name: "SDDM (Best for KDE/Niri)"
      selected: true
      packages: [ sddm, sddm-kcm ]
    - name: "GDM (Best for GNOME)"
      packages: [ gdm ]
    - name: "LightDM"
      packages: [ lightdm, lightdm-gtk ]
    - name: "Cosmic Greeter"
      packages: [ cosmic-greeter ]
    - name: "Ly (Console)"
      packages: [ ly ]
    - name: "TUI Greet (Greetd)"
      packages: [ greetd, greetd-tuigreet ]
EOF

# YAML 3: SOFTWARE
cat > /etc/calamares/modules/netinstall-software.yaml << 'EOF'
- name: "Web Browsers"
  expanded: true
  groups:
    - name: "Zen Browser (Default)"
      selected: true
      packages: [ zen-browser ]
    - name: "Brave"
      packages: [ brave-browser ]
    - name: "Firefox"
      packages: [ firefox ]
    - name: "Chromium"
      packages: [ chromium ]

- name: "System Protection"
  groups:
    - name: "Snapper & Btrfs Assistant"
      packages: [ snapper, btrfs-assistant, python3-dnf-plugin-snapper ]

- name: "Shells (Optional)"
  groups:
    - name: "Apex ZSH (Peak)"
      description: "Pre-configured with Starship & Fastfetch"
      selected: false
      packages: [ apex-config-shell ]
    - name: "Fish"
      selected: false
      packages: [ fish, starship ]

- name: "Office (Optional)"
  groups:
    - name: "LibreOffice"
      selected: false
      packages: [ libreoffice ]
    - name: "OnlyOffice"
      selected: false
      packages: [ onlyoffice-desktopeditors ]

- name: "System Fonts"
  groups:
    - name: "Standard Fonts"
      selected: true
      packages: [ google-noto-sans-fonts, google-noto-serif-fonts, google-noto-emoji-fonts ]
    - name: "Nerd Fonts (Symbols)"
      selected: true
      packages: [ jetbrains-mono-fonts-all, fira-code-fonts ]
EOF

# INIT DNF
cat > /usr/bin/apex-init-dnf << 'SCRIPT'
#!/bin/bash
echo ">>> [APEX] Initializing Package Manager..."
if [ ! -f /etc/yum.repos.d/brave-browser.repo ]; then
    dnf config-manager --add-repo https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo
    rpm --import https://brave-browser-rpm-release.s3.brave.com/brave-core.asc
fi
if [ ! -f /etc/yum.repos.d/onlyoffice.repo ]; then
    dnf install -y https://download.onlyoffice.com/repo/centos/main/noarch/onlyoffice-repo.noarch.rpm
fi
dnf makecache --refresh
SCRIPT
chmod +x /usr/bin/apex-init-dnf

cat > /etc/calamares/modules/shellprocess-init.conf << 'EOF'
i18n:
    name: "Refreshing Package Data..."
dontChroot: false
timeout: 60
script:
    - command: "/usr/bin/apex-init-dnf"
EOF

# FINAL PROCESS
cat > /etc/calamares/modules/shellprocess-final.conf << 'EOF'
i18n:
    name: "System Finalization..."
dontChroot: false
timeout: 900
script:
    - command: "-chroot /usr/bin/apex-hw-detect"
    - command: "-chroot /usr/bin/apex-bootloader-setup"
    - command: "-chroot /usr/bin/apex-dm-enforce"
    - command: "touch /var/lib/calamares/root/.autorelabel"
    - command: "-chroot /usr/bin/dracut --regenerate-all --force"
    - command: "-chroot /bin/sh -c 'if [ -x /usr/bin/snapper ]; then snapper -c root create-config /; fi'"
    
    # Conditional Performance Tuner Enable
    - command: "-chroot /bin/sh -c 'if rpm -q apex-tuning; then systemctl enable apex-scheduler.service; fi'"
    
    - command: "-chroot /usr/bin/systemctl enable cups bluetooth"
EOF

# ... [Standard Calamares Configs + Branding Assets (Unchanged)] ...
cat > /etc/calamares/modules/displaymanager.conf << 'EOF'
displaymanagers:
  - sddm
  - gdm
  - lightdm
  - greetd
  - ly
  - cosmic-greeter
basicSetup: false
sysconfigSetup: false
EOF
cat > /etc/calamares/modules/services-systemd.conf << 'EOF'
services:
  - NetworkManager
  - bluetooth
  - power-profiles-daemon
  - cups
  - fstrim.timer
EOF
cat > /etc/calamares/modules/packages.conf << 'EOF'
backend: dnf
skip_if_no_internet: false
update_db: true
update_system: false
operations:
  - remove:
      - calamares
      - calamares-libs
      - livecd-tools
      - apex-branding-live
      - kpmcore
      - python3-libcalamares
EOF
cat > /etc/calamares/modules/removeuser.conf << 'EOF'
username: liveuser
EOF
cat > /etc/calamares/modules/machineid.conf << 'EOF'
systemd: true
dbus: true
symlink: true
EOF
cat > /etc/calamares/modules/mount.conf << 'EOF'
extraMounts:
    - device: proc
      fs: proc
      mountPoint: /proc
    - device: sys
      fs: sysfs
      mountPoint: /sys
btrfsSubvolumes:
    - mountPoint: /
      subvolume: /@
    - mountPoint: /home
      subvolume: /@home
    - mountPoint: /var/cache
      subvolume: /@cache
    - mountPoint: /var/log
      subvolume: /@log
    - mountPoint: /var/tmp
      subvolume: /@tmp
    - mountPoint: /.snapshots
      subvolume: /@snapshots
btrfsSwapSubvol: /@swap
EOF
cat > /etc/calamares/settings.conf << 'EOF'
modules-search: [ local ]
instances:
- id:       init
  module:   shellprocess
  config:   shellprocess-init.conf
- id:       final
  module:   shellprocess
  config:   shellprocess-final.conf
- id:       desktop
  module:   netinstall
  config:   netinstall-desktop.conf
- id:       dm
  module:   netinstall
  config:   netinstall-dm.conf
- id:       software
  module:   netinstall
  config:   netinstall-software.conf
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
  - netinstall@desktop
  - netinstall@dm
  - netinstall@software
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
  - shellprocess@init
  - netinstall@desktop
  - netinstall@dm
  - netinstall@software
  - shellprocess@final
  - displaymanager
  - services-systemd
  - hwclock
  - packages
  - removeuser
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
cat > /usr/share/calamares/branding/apex/branding.desc << 'EOF'
---
componentName:  apex
welcomeStyleCalamares:   true
welcomeExpandingLogo:   true
windowExpanding:    normal
windowSize: 1024px,768px
windowPlacement: center
sidebar: qml,left
navigation: qml,right
strings:
    productName:         "Apex Linux"
    shortProductName:    "Apex"
    version:             "1.0"
    shortVersion:        "1.0"
    versionedName:       "Apex Linux 1.0 (Genesis)"
    shortVersionedName:  "Apex Genesis"
    bootloaderEntryName: "Apex Linux"
    productUrl:          "https://apexlinux.org"
    supportUrl:          "https://apexlinux.org/support"
    knownIssuesUrl:      "https://github.com/Apex-Linux/issues"
    releaseNotesUrl:     "https://apexlinux.org/blog"
    donateUrl:           "https://apexlinux.org/donate"
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
cat > /usr/share/calamares/branding/apex/sidebar.qml << 'EOF'
import QtQuick
import calamares.branding 1.0
Rectangle {
    id: sidebar
    width: 200
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    anchors.left: parent.left
    color: Branding.styleString(Branding.SidebarBackground)
    Column {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
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
cat > /usr/share/calamares/branding/apex/show.qml << 'EOF'
import QtQuick
import calamares.slideshow 1.0
Presentation {
    id: presentation
    Timer { interval: 5000; running: true; repeat: true; onTriggered: presentation.goToNextSlide() }
    
    // CUSTOM INSTALLER BACKGROUND
    Image {
        anchors.fill: parent
        source: "install_bg.png"
        fillMode: Image.PreserveAspectCrop
        smooth: true
    }

    Slide {
        anchors.fill: parent
        Text {
            anchors.centerIn: parent
            text: "Welcome to Apex Linux<br/><br/>Fast. Beautiful. Yours."
            color: "white"
            font.pixelSize: 24
            horizontalAlignment: Text.AlignCenter
            style: Text.Outline
            styleColor: "black" // Improves readability on complex backgrounds
        }
    }
}
EOF
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
