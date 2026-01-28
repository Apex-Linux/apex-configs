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

echo 'add_drivers+=" overlay squashfs loop dm-mod "' > /etc/dracut.conf.d/10-apex-live.conf

if systemctl list-unit-files | grep -q zramswap.service; then
    systemctl enable zramswap
fi

# --- 2. PERMISSIONS REPAIR (The Fix for Log Warnings) ---
# This fixes "wrong owner/group" errors for unix_chkpwd, fusermount, etc.
if [ -x /usr/bin/chkstat ]; then
    echo "Running chkstat to fix system permissions..."
    chkstat --system
fi

# Ensure Polkit dir exists and has correct permissions
mkdir -p /etc/polkit-1/rules.d/
chmod 750 /etc/polkit-1/rules.d/
chown polkitd:root /etc/polkit-1/rules.d/ 2>/dev/null || true

# Regenerate Polkit privileges
[ -x /usr/sbin/set_polkit_default_privs ] && /usr/sbin/set_polkit_default_privs

# --- 3. User Setup ---

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

# --- 4. REPO INJECTION ---
echo "--- Injecting Official Tumbleweed Repositories ---"
zypper ar -f -n "openSUSE Tumbleweed OSS" http://download.opensuse.org/tumbleweed/repo/oss/ repo-oss
zypper ar -f -n "openSUSE Tumbleweed Non-OSS" http://download.opensuse.org/tumbleweed/repo/non-oss/ repo-non-oss
zypper ar -f -n "openSUSE Tumbleweed Update" http://download.opensuse.org/update/tumbleweed/ repo-update

zypper --gpg-auto-import-keys ref || true

# --- 5. Desktop Finalization ---

systemctl enable NetworkManager sddm

if [ -f /usr/lib/systemd/system/sddm.service ]; then
    mkdir -p /etc/systemd/system/graphical.target.wants
    ln -sf /usr/lib/systemd/system/sddm.service /etc/systemd/system/display-manager.service
    ln -sf /usr/lib/systemd/system/sddm.service /etc/systemd/system/graphical.target.wants/sddm.service
fi

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

# Fix podman capabilities
for bin in /usr/bin/newuidmap /usr/bin/newgidmap; do
    if [ -x "$bin" ]; then
        if command -v setcap >/dev/null 2>&1; then
            [[ "$bin" == *newuidmap ]] && setcap cap_setuid+ep "$bin" || setcap cap_setgid+ep "$bin"
        else
            chmod 4755 "$bin"
        fi
    fi
done

sed -i 's/^solver.onlyRequires.*/solver.onlyRequires = false/' /etc/zypp/zypp.conf
systemctl set-default graphical.target
[ -x /usr/bin/systemd-hwdb ] && systemd-hwdb update || true

exit 0
