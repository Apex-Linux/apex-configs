#!/bin/bash
# Exit if any command fails
set -e

# --- Networking ---
systemctl enable NetworkManager

# --- Display Manager ---
# Force enable SDDM to ensure it takes precedence
systemctl enable --force sddm

# --- Force Plasma 6 Wayland Session ---
# Per 2026 Tumbleweed standards, we use plasmawayland.desktop
mkdir -p /etc/sddm.conf.d
cat > /etc/sddm.conf.d/10-wayland.conf << EOF
[General]
DisplayServer=wayland
[Autologin]
Session=plasmawayland.desktop
EOF

# --- Branding (Apex Linux Identity) ---
if [ -f /etc/os-release ]; then
    cat > /etc/os-release << EOF
NAME="Apex Linux"
VERSION="Kde Edition"
ID=apexlinux
ID_LIKE="suse opensuse"
PRETTY_NAME="Apex Linux Kde Edition"
ANSI_COLOR="0;34"
CPE_NAME="cpe:/o:apexlinux:apexlinux:2026"
HOME_URL="https://github.com/Apex-Linux/apex-configs"
VARIANT="Plasma 6 Edition"
VARIANT_ID=plasma
EOF
fi

# Set the hostname
echo "apex-linux" > /etc/hostname

# --- System & Performance Tweaks ---
# Keeps the Live ISO lightweight by skipping unnecessary recommended packages
sed -i 's/^# solver.onlyRequires.*/solver.onlyRequires = true/' /etc/zypp/zypp.conf

# Rebuild hardware database for Live ISO driver detection
systemd-hwdb update
udevadm trigger

echo "Apex Linux DNA successfully initialized!"
exit 0
