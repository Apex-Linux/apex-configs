#!/bin/bash
# Exit if any command fails
set -e

# --- Networking ---
systemctl enable NetworkManager

# --- Display Manager ---
# Force enable SDDM to ensure it takes precedence
systemctl enable --force sddm

# --- Force Plasma 6 Wayland Session ---
# This ensures SDDM defaults to the modern Wayland session on first boot.
mkdir -p /etc/sddm.conf.d
cat > /etc/sddm.conf.d/10-wayland.conf << EOF
[General]
DisplayServer=wayland
[Autologin]
Session=plasma6.desktop
EOF

# --- Branding (Apex Linux Identity) ---
if [ -f /etc/os-release ]; then
    cat > /etc/os-release << EOF
NAME="Apex Linux"
VERSION="Tumbleweed Edition"
ID=apexlinux
ID_LIKE="suse opensuse"
PRETTY_NAME="Apex Linux Tumbleweed Edition"
ANSI_COLOR="0;34"
CPE_NAME="cpe:/o:apexlinux:apexlinux:2026"
HOME_URL="https://github.com/yourproject"
VARIANT="Plasma 6 Edition"
VARIANT_ID=plasma
EOF
fi

# Set the hostname
echo "apex-linux" > /etc/hostname

# --- System & Performance Tweaks ---
# Force Zypper to avoid installing recommended packages (keeps the ISO small)
sed -i 's/^# solver.onlyRequires.*/solver.onlyRequires = true/' /etc/zypp/zypp.conf

# Rebuild hardware database for Live ISO driver detection
systemd-hwdb update
udevadm trigger

echo "Apex Linux DNA successfully initialized!"
exit 0
