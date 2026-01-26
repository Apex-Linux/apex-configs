#!/bin/bash
# Exit if any command fails
set -e

# --- Networking ---
# Activate NetworkManager so the ISO has internet out of the box
systemctl enable NetworkManager
# Enable the display manager for KDE
systemctl enable sddm

# --- Branding (Apex Linux Identity) ---
# This re-labels the system so it identifies as Apex
if [ -f /etc/os-release ]; then
    sed -i 's/openSUSE Tumbleweed/Apex Linux/g' /etc/os-release
    sed -i 's/^NAME=.*/NAME="Apex Linux"/' /etc/os-release
    sed -i 's/^ID=.*/ID=apexlinux/' /etc/os-release
    # Force Zypper to NOT install recommended packages globally
    sed -i 's/^# solver.onlyRequires.*/solver.onlyRequires = true/' /etc/zypp/zypp.conf
    sed -i 's/^PRETTY_NAME=.*/PRETTY_NAME="Apex Linux Tumbleweed Edition"/' /etc/os-release
fi

# Set the hostname
echo "apex-linux" > /etc/hostname

echo "Apex Linux DNA successfully initialized!"
exit 0
