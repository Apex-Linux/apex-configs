#!/usr/bin/env bash
# Apex Linux - Distribution Configuration Script
# Target: OpenSUSE Tumbleweed Base (Plasma 6)

set -euo pipefail

# --- Configuration Variables ---
LIVE_USER="apex"
LIVE_PASS="live"
HOSTNAME="apex-linux"

# --- 1. System & Boot Configuration ---

# Ensure root
if [ "$(id -u)" -ne 0 ]; then
    echo "Error: This script must be run as root." >&2
    exit 1
fi

# Enable Standard Live Drivers
echo 'add_drivers+=" overlay squashfs loop dm-mod "' > /etc/dracut.conf.d/10-apex-live.conf

# Enable zRAM
if systemctl list-unit-files | grep -q zramswap.service; then
    systemctl enable zramswap
fi

# --- 2. User & Security Setup ---

# Create generic groups if missing
for group in wheel video audio users render shadow; do
    getent group "$group" >/dev/null 2>&1 || groupadd -r "$group"
done

# Set Root Password
echo "root:linux" | chpasswd

# Setup Live User
if ! id "$LIVE_USER" &>/dev/null; then
    useradd -m -s /bin/bash -c "Apex Live User" -G wheel,video,audio,users,render "$LIVE_USER"
    # Set fallback password
    echo "$LIVE_USER:$LIVE_PASS" | chpasswd
    
    # Sudoers configuration
    echo "$LIVE_USER ALL=(ALL) NOPASSWD: ALL" > "/etc/sudoers.d/$LIVE_USER"
    chmod 0440 "/etc/sudoers.d/$LIVE_USER"
    
    # Podman/Container mapping setup
    touch /etc/subuid /etc/subgid
    grep -q "^${LIVE_USER}:" /etc/subuid || echo "${LIVE_USER}:100000:65536" >> /etc/subuid
    grep -q "^${LIVE_USER}:" /etc/subgid || echo "${LIVE_USER}:100000:65536" >> /etc/subgid
fi

# Polkit Permissions Fix
mkdir -p /etc/polkit-1/rules.d/
chmod 750 /etc/polkit-1/rules.d/
chown polkitd:root /etc/polkit-1/rules.d/ 2>/dev/null || true

# Regenerate openSUSE privs
[ -x /usr/sbin/set_polkit_default_privs ] && /usr/sbin/set_polkit_default_privs

# --- 3. Desktop & Display Manager ---

# Enable basic services
systemctl enable NetworkManager sddm

# Fix SDDM Service Symlinks
if [ -f /usr/lib/systemd/system/sddm.service ]; then
    mkdir -p /etc/systemd/system/graphical.target.wants
    ln -sf /usr/lib/systemd/system/sddm.service /etc/systemd/system/display-manager.service
    ln -sf /usr/lib/systemd/system/sddm.service /etc/systemd/system/graphical.target.wants/sddm.service
fi

# Configure SDDM Autologin (Wayland)
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

# --- 4. Branding & Finalization ---

# Set Hostname
echo "$HOSTNAME" > /etc/hostname

# Set OS Release Info
cat > /etc/os-release << EOF
NAME="Apex Linux"
VERSION="2026 (Plasma 6)"
ID=apexlinux
ID_LIKE="suse opensuse tumbleweed"
PRETTY_NAME="Apex Linux Plasma 6"
VARIANT="Live"
HOME_URL="https://github.com/Apex-Linux"
EOF

# Fix SetUID permissions
for bin in /usr/bin/newuidmap /usr/bin/newgidmap; do
    if [ -x "$bin" ]; then
        if command -v setcap >/dev/null 2>&1; then
            [[ "$bin" == *newuidmap ]] && setcap cap_setuid+ep "$bin" || setcap cap_setgid+ep "$bin"
        else
            chmod 4755 "$bin"
        fi
    fi
done

# --- SOLVER UNLOCK ---
# Critical: Allow Zypper to use the new repo to fix dependencies
sed -i 's/^solver.onlyRequires.*/solver.onlyRequires = false/' /etc/zypp/zypp.conf

# Set default boot target
systemctl set-default graphical.target

# Update Hardware Database
[ -x /usr/bin/systemd-hwdb ] && systemd-hwdb update || true

exit 0
