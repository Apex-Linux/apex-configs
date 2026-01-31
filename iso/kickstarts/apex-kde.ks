# Apex Linux KDE Edition
# Version: 2026.1

# INCLUDE SHARED COMPONENTS
%include apex-base.ks
%include apex-branding.ks

# === KDE PACKAGES ===
%packages
# Desktop Environment
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

# Remove KDE Bloat
-plasma-welcome
-plasma-welcome-agent
-libreoffice-*
-thunderbird
-firefox*
-kmail
-kontact
-akregator
-dragon
-elisa
-okular
-kmines
-kmahjongg
-kpat
-dnfdragora
%end

# === KDE SPECIFIC CONFIG ===
%post
# 1. DARK MODE SETUP
mkdir -p /home/liveuser/.config
mkdir -p /etc/skel/.config
cat > /tmp/kdeglobals << 'EOF'
[General]
ColorScheme=BreezeDark
Name=Breeze Dark
[KDE]
LookAndFeelPackage=org.kde.breezedark.desktop
EOF
cp /tmp/kdeglobals /home/liveuser/.config/kdeglobals
cp /tmp/kdeglobals /etc/skel/.config/kdeglobals
chown -R liveuser:liveuser /home/liveuser/.config

# 2. ENABLE SERVICES
systemctl enable sddm
systemctl enable NetworkManager

# 2. AUTOLOGIN
mkdir -p /etc/sddm.conf.d
cat > /etc/sddm.conf.d/autologin.conf << EOF
[Autologin]
User=liveuser
Session=plasma
EOF

# 3. CLEANUP
rm -f /var/lib/systemd/random-seed
dnf clean all
%end
