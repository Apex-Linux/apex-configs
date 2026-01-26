#!/bin/bash
# Exit if any command fails
set -e

# --- Networking ---
systemctl enable NetworkManager

# --- Display Manager ---
# Use --force to overwrite the existing display-manager-legacy symlink
systemctl enable --force sddm

# --- Branding (Apex Linux Identity) ---
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
