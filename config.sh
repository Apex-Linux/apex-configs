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

# Ensure dracut is configured for the live system
echo 'add_drivers+=" overlay squashfs loop dm-mod "' > /etc/dracut.conf.d/10-apex-live.conf

# Enable zram if present
if systemctl list-unit-files | grep -q zramswap.service; then
    systemctl enable zramswap
fi

# --- 2. PERMISSIONS & POLKIT REPAIR ---
# FIX: Create Polkit directory early to prevent scriptlet failure
mkdir -p /etc/polkit-1/rules.d/
chmod 750 /etc/polkit-1/rules.d/
chown polkitd:root /etc/polkit-1/rules.d/ 2>/dev/null || true

# Fix "wrong owner/group" warnings for system binaries
if [ -x /usr/bin/chkstat ]; then
    echo "Running chkstat to fix system permissions..."
    chkstat --system
fi

# Regenerate Polkit privileges
if [ -x /usr/sbin/set_polkit_default_privs ]; then
    /usr/sbin/set_polkit_default_privs
fi

# --- 3. User Setup ---
# Ensure essential groups exist
for group in wheel video audio users render shadow; do
    getent group "$group" >/dev/null 2>&1 || groupadd -r "$group"
done

echo "root:linux" | chpasswd

if ! id "$LIVE_USER" &>/dev/null; then
    useradd -m -s /bin/bash -c "Apex Live User" -G wheel,video,audio,users,render "$LIVE_USER"
    echo "$LIVE_USER:$LIVE_PASS" | chpasswd
    echo "$LIVE_USER ALL=(ALL) NOPASSWD: ALL" > "/etc/sudoers.d/$LIVE_USER"
    chmod 0440 "/etc/sudoers.d/$LIVE_USER"
fi

# --- 5. Desktop Finalization ---
systemctl enable NetworkManager
systemctl enable sddm

# Configure SDDM autologin
mkdir -p /etc/sddm.conf.d
SESSION_FILE=$(find /usr/share/wayland-sessions -name "*plasma*.desktop" | head -n1 || echo "plasma.desktop")
SESSION_NAME=$(basename "$SESSION_FILE")

cat > /etc/sddm.conf.d/autologin.conf << EOF
[General]
DisplayServer=wayland
GreeterEnvironment=QT_WAYLAND_SHELL_INTEGRATION=layer-shell

[Autologin]
User=${LIVE_USER}
Session=${SESSION_NAME}
Relogin=false
EOF

# Branding & Hostname
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

# --- 6. Security & Cleanup ---
# Fix capabilities for rootless containers
for bin in /usr/bin/newuidmap /usr/bin/newgidmap; do
    if [ -x "$bin" ]; then
        if command -v setcap >/dev/null 2>&1; then
            [[ "$bin" == *newuidmap ]] && setcap cap_setuid+ep "$bin" || setcap cap_setgid+ep "$bin"
        else
            chmod 4755 "$bin"
        fi
    fi
done

# Set default boot target
systemctl set-default graphical.target

# Update system databases
sed -i 's/^solver.onlyRequires.*/solver.onlyRequires = false/' /etc/zypp/zypp.conf
[ -x /usr/bin/systemd-hwdb ] && systemd-hwdb update || true

exit 0
