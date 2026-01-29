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

# Ensure graphics drivers and live media support are included in the initrd
# This prevents black screens by initializing video output early in the boot.
echo 'add_drivers+=" overlay squashfs loop dm-mod virtio virtio_gpu drm drm_kms_helper "' > /etc/dracut.conf.d/10-apex-live.conf

# Enable zram for better performance on live media if the service is available
if systemctl list-unit-files | grep -q zramswap.service; then
    systemctl enable zramswap
fi

# --- 2. PERMISSIONS & POLKIT REPAIR ---
# Explicitly create Polkit directory to ensure correct ownership
mkdir -p /etc/polkit-1/rules.d/
chmod 750 /etc/polkit-1/rules.d/
chown polkitd:root /etc/polkit-1/rules.d/ 2>/dev/null || true

# Regenerate Polkit privileges to ensure authentication works correctly on first boot
if [ -x /usr/sbin/set_polkit_default_privs ]; then
    /usr/sbin/set_polkit_default_privs
fi

# --- 3. User & Root Setup ---
# Ensure essential groups exist for the user environment
for group in wheel video audio users render shadow; do
    getent group "$group" >/dev/null 2>&1 || groupadd -r "$group"
done

# Set root password
echo "root:linux" | chpasswd

# Create the primary live user
if ! id "$LIVE_USER" &>/dev/null; then
    useradd -m -s /bin/bash -c "Apex Live User" -G wheel,video,audio,users,render "$LIVE_USER"
    echo "$LIVE_USER:$LIVE_PASS" | chpasswd
    echo "$LIVE_USER ALL=(ALL) NOPASSWD: ALL" > "/etc/sudoers.d/$LIVE_USER"
    chmod 0440 "/etc/sudoers.d/$LIVE_USER"
fi

# PERMISSION STAMP: Correct binary ownership for authentication tools (e.g., unix_chkpwd)
# This must run after user creation to ensure the shadow file is audited.
if [ -x /usr/bin/chkstat ]; then
    echo "Stamping system permissions..."
    chkstat --system
fi

# --- 4. Desktop Finalization (The Black Screen Fix) ---
# Set the default boot target and force-enable the display manager
systemctl set-default graphical.target
systemctl enable NetworkManager
systemctl enable --force sddm

# Configure SDDM autologin for Plasma 6 (Wayland)
mkdir -p /etc/sddm.conf.d

# Dynamically find the Plasma session file and strip the extension for the config
SESSION_PATH=$(find /usr/share/wayland-sessions -name "*plasma*.desktop" | head -n1)
if [ -n "$SESSION_PATH" ]; then
    SESSION_NAME=$(basename "$SESSION_PATH" .desktop)
else
    # Fallback to standard Tumbleweed Plasma session name
    SESSION_NAME="plasma"
fi

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
# Manually apply capabilities to mapping tools for rootless container support
if command -v setcap >/dev/null 2>&1; then
    echo "Applying file capabilities to newuidmap and newgidmap..."
    setcap cap_setuid+ep /usr/bin/newuidmap
    setcap cap_setgid+ep /usr/bin/newgidmap
else
    # Fallback to SUID if setcap is not present
    chmod 4755 /usr/bin/newuidmap /usr/bin/newgidmap
fi

# Update system databases and hardware identification
sed -i 's/^solver.onlyRequires.*/solver.onlyRequires = false/' /etc/zypp/zypp.conf
[ -x /usr/bin/systemd-hwdb ] && systemd-hwdb update || true

exit 0
