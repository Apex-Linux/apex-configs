#!/bin/bash
# Exit if any command fails
set -e

# --- Networking ---
systemctl enable NetworkManager

# --- Display Manager & Desktop ---
# In 2026, sddm often needs to be forced over the legacy 'xdm' or 'display-manager' service
systemctl enable --force sddm

# Set Plasma 6 Wayland as the default session for all users
# This prevents the 'black screen' or 'X11 fallback' on first boot
mkdir -p /etc/sddm.conf.d
cat > /etc/sddm.conf.d/10-wayland.conf << EOF
[General]
DisplayServer=wayland
[Autologin]
Session=plasma
EOF

# --- Branding (Apex Linux Identity) ---
# We use a cleaner approach to overwrite the identity files
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

# --- System Tweaks ---
# Force Zypper to stay slim
sed -i 's/^# solver.onlyRequires.*/solver.onlyRequires = true/' /etc/zypp/zypp.conf

# Rebuild the hardware database (crucial for Live ISO hardware detection)
systemd-hwdb update
udevadm trigger

echo "Apex Linux DNA successfully initialized!"
exit 0
