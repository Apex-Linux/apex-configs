# === APEX LINUX KDE EDITION ===
# Version: 2026.1
# Description: Package definitions and Service activation only.

# INCLUDE SHARED COMPONENTS
%include apex-base.ks
%include apex-branding.ks

# === KDE PACKAGES ===
%packages
# Core Desktop
plasma-desktop
plasma-workspace
plasma-workspace-wayland
sddm
kwin
konsole
dolphin
ark
spectacle
kate
gwenview
polkit-kde

# Network & Audio
NetworkManager-wifi
plasma-nm
pipewire
pipewire-alsa
pipewire-pulseaudio
wireplumber

# === BLOAT REMOVAL (Kill List) ===
# 1. Kill Discover (App Store) completely
-libsForQt5.discover
-plasma-discover
-plasma-discover-notifier
-discover
-rpmostree-client

# 2. Remove Fedora/KDE Defaults we don't want
-plasma-welcome
-plasma-welcome-agent
-dnfdragora
-kmail
-kontact
-akregator
-dragon
-elisa
-okular
-kmines
-kmahjongg
-kpat
-libreoffice-*
-thunderbird
-firefox*
%end

# === SYSTEM CONFIGURATION ===
%post
# 1. ENABLE CRITICAL SERVICES
systemctl enable sddm
systemctl enable NetworkManager

# 2. CONFIGURE AUTOLOGIN (For Live ISO)
mkdir -p /etc/sddm.conf.d
cat > /etc/sddm.conf.d/autologin.conf << EOF
[Autologin]
User=liveuser
Session=plasma
EOF

# 3. CLEANUP
# Remove random seed to ensure unique keys on new installs
rm -f /var/lib/systemd/random-seed
dnf clean all
%end
