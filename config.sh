#!/usr/bin/env bash
# Apex Linux - Distribution Configuration Script
# Target: OpenSUSE Tumbleweed Base (Plasma 6)

set -euo pipefail

# --- Configuration Variables ---
LIVE_USER="apex"
LIVE_PASS="live"
HOSTNAME="apex-linux"

# --- 1. System & Boot Configuration ---
if [ "$(id -u)" -ne 0 ]; then
    echo "Error: This script must be run as root." >&2
    exit 1
fi

# Configure dracut for the live environment
echo 'add_drivers+=" overlay squashfs loop dm-mod "' > /etc/dracut.conf.d/10-apex-live.conf

# Enable zram if the service is present
if systemctl list-unit-files | grep -q zramswap.service; then
    systemctl enable zramswap
fi

# --- 2. PERMISSIONS & POLKIT REPAIR ---
# Ensure Polkit directory exists and has correct permissions
mkdir -p /etc/polkit-1/rules.d/
chmod 750 /etc/polkit-1/rules.d/
chown polkitd:root /etc/polkit-1/rules.d/ 2>/dev/null || true

# THE ROOT FIX: Correct "wrong owner/group" warnings for system binaries
# This ensures unix_chkpwd is root:shadow so login doesn't fail.
if [ -x /usr/bin/chkstat ]; then
    echo "Running chkstat to fix system permissions..."
    chkstat --system
fi

# Regenerate Polkit privileges to ensure sudo/auth work on first boot
if [ -x /usr/sbin/set_polkit_default_privs ]; then
    /usr/sbin/set_polkit_default_privs
fi

# --- 3. User & Root Setup ---
# Ensure essential groups exist for the live user
for group in wheel video audio users render shadow; do
    getent group "$group" >/dev/null 2>&1 || groupadd -r "$group"
done

# Set root password (Backbone authentication fix)
echo "root:linux" | chpasswd

# Create the Apex Live User
if ! id "$LIVE_USER" &>/dev/null; then
    useradd -m -s /bin/bash -c "Apex Live User" -G wheel,video,audio,users,render "$LIVE_USER"
    echo "$LIVE_USER:$LIVE_PASS" | chpasswd
    echo "$LIVE_USER ALL=(ALL) NOPASSWD: ALL" > "/etc/sudoers.d/$LIVE_USER"
    chmod 0440 "/etc/sudoers.d/$LIVE_USER"
fi

# --- 4. Desktop Finalization (THE BLACK SCREEN FIX) ---
# FIX: Use --force to overwrite legacy symlinks and ensure SDDM loads
systemctl set-default graphical.target
systemctl enable NetworkManager
systemctl enable --force sddm

# Configure SDDM autologin for Plasma 6 (Wayland)
mkdir -p /etc/sddm.conf.d
SESSION_FILE=$(find /usr/share/wayland-sessions -name "*plasma*.desktop" | head -n1 || echo "plasma-wayland.desktop")
SESSION_NAME=$(basename "$SESSION_FILE" .desktop)

cat > /etc/sddm.conf.d/autologin.conf << EOF
[General]
DisplayServer=wayland
GreeterEnvironment=QT_WAYLAND_SHELL_INTEGRATION=layer-shell

[Autologin]
User=${LIVE_USER}
Session=${SESSION_NAME}
Relogin=false
EOF

# --- 5. Identity & Branding ---
echo "$HOSTNAME" > /etc/hostname

cat > /etc/os-release << EOF
NAME="Apex Linux"
VERSION="2026 (Plasma 6)"
ID=apexlinux
ID_LIKE="suse opensuse tumbleweed"
PRETTY_NAME="Apex Linux Plasma 6"
VARIANT="Live"
HOME_URL="https://github.com/Apex-Linux"
EOF

# --- 6. Security & Capabilities ---
# CAPABILITY FIX: Manually apply caps to fix Podman/Rootless warnings in logs
if command -v setcap >/dev/null 2>&1; then
    echo "Applying file capabilities to newuidmap and newgidmap..."
    setcap cap_setuid+ep /usr/bin/newuidmap
    setcap cap_setgid+ep /usr/bin/newgidmap
else
    # Fallback to SUID if setcap is missing
    chmod 4755 /usr/bin/newuidmap /usr/bin/newgidmap
fi

# Update system databases
sed -i 's/^solver.onlyRequires.*/solver.onlyRequires = false/' /etc/zypp/zypp.conf
[ -x /usr/bin/systemd-hwdb ] && systemd-hwdb update || true

exit 0
