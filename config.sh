#!/usr/bin/env bash
set -euo pipefail

# --- OFFICIAL DRACUT CONFIGURATION ---
echo 'add_drivers+=" overlay squashfs loop "' > /etc/dracut.conf.d/force-drivers.conf

# --- Safety Check: Ensure Root ---
if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: Apex DNA initialization must be run as root!" >&2
    exit 1
fi

LIVE_USER="apex"
LIVE_PASS="live" 

echo "--- [1/5] Initializing User & Group Security ---"

getent group shadow >/dev/null || groupadd -r shadow

ensure_group() {
    local g="$1"
    if getent group "$g" >/dev/null 2>&1; then
        echo "  [OK] Group '$g' already exists."
    else
        groupadd "$g" && echo "  [NEW] Group '$g' created."
    fi
}

for g in wheel video audio users render; do
    ensure_group "$g"
done

echo "root:linux" | chpasswd

if ! id "$LIVE_USER" &>/dev/null; then
    useradd -m -s /bin/bash -G wheel,video,audio,users,render "$LIVE_USER"
    echo "$LIVE_USER:$LIVE_PASS" | chpasswd
    
    cat > /etc/sudoers.d/apex <<'EOF'
apex ALL=(ALL) NOPASSWD: ALL
EOF
    chmod 0440 /etc/sudoers.d/apex
    
    # Container Support
    touch /etc/subuid /etc/subgid
    chmod 0644 /etc/subuid /etc/subgid
    grep -q "^${LIVE_USER}:" /etc/subuid || echo "${LIVE_USER}:100000:65536" >> /etc/subuid
    grep -q "^${LIVE_USER}:" /etc/subgid || echo "${LIVE_USER}:100000:65536" >> /etc/subgid
else
    echo "  [SKIP] User '$LIVE_USER' already exists."
fi

echo "--- [2/5] Configuring Services & Polkit ---"

# --- POLKIT REPAIR (Standard Fix) ---
mkdir -p /etc/polkit-1/rules.d/
chmod 750 /etc/polkit-1/rules.d/ 
chown polkitd:root /etc/polkit-1/rules.d/ 2>/dev/null || true

if [ -x /usr/sbin/set_polkit_default_privs ]; then
    /usr/sbin/set_polkit_default_privs
fi

# Enable critical services
systemctl enable NetworkManager 2>/dev/null || true
systemctl enable sddm 2>/dev/null || true

# Enable zRAM
if systemctl list-unit-files | grep -q zramswap.service; then
    systemctl enable zramswap
fi

for possible in /usr/lib/systemd/system/sddm.service /lib/systemd/system/sddm.service; do
  if [ -f "$possible" ]; then
    mkdir -p /etc/systemd/system/graphical.target.wants
    ln -sf "$possible" /etc/systemd/system/display-manager.service
    ln -sf "$possible" /etc/systemd/system/graphical.target.wants/sddm.service
    break
  fi
done

echo "--- [3/5] Detecting Plasma 6 Wayland Session ---"
mkdir -p /etc/sddm.conf.d
find_session() {
    local candidate
    candidate=$(find /usr/share/wayland-sessions /usr/share/xsessions -maxdepth 1 -type f -name '*plasma*.desktop' 2>/dev/null | head -n1 || true)
    [ -z "$candidate" ] && candidate=$(find /usr/share/wayland-sessions /usr/share/xsessions -maxdepth 1 -type f -name '*.desktop' 2>/dev/null | head -n1 || true)
    [ -n "$candidate" ] && basename "$candidate" || echo "plasmawayland.desktop"
}
SESSION="$(find_session)"

cat > /etc/sddm.conf.d/10-wayland.conf << EOF
[General]
DisplayServer=wayland
GreeterEnvironment=QT_WAYLAND_SHELL_INTEGRATION=layer-shell

[Autologin]
User=${LIVE_USER}
Session=${SESSION}
Relogin=false
EOF

echo "--- [4/5] Applying Apex Linux Branding ---"
cat > /etc/os-release << 'EOF'
NAME="Apex Linux"
VERSION="2026 (Plasma 6 Edition)"
ID=apexlinux
ID_LIKE="suse opensuse tumbleweed"
PRETTY_NAME="Apex Linux Plasma 6 Edition"
VARIANT="KDE Plasma 6"
HOME_URL="https://github.com/Apex-Linux"
EOF
echo "apex-linux" > /etc/hostname

echo "--- [5/5] Final Hardware & System Tweaks ---"
for bin in /usr/bin/newuidmap /usr/bin/newgidmap; do
    if [ -x "$bin" ]; then
        chown root:root "$bin"
        if command -v setcap >/dev/null 2>&1; then
            [[ "$bin" == *newuidmap ]] && setcap cap_setuid+ep "$bin" || setcap cap_setgid+ep "$bin"
        else
            chmod 4755 "$bin"
        fi
    fi
done

systemctl set-default graphical.target
[ -x /usr/bin/systemd-hwdb ] && systemd-hwdb update || true

ZYPP_CONF="/etc/zypp/zypp.conf"
if [ -f "$ZYPP_CONF" ]; then
    sed -i 's/^# solver.onlyRequires.*/solver.onlyRequires = true/' "$ZYPP_CONF"
    sed -i 's/^solver.onlyRequires.*/solver.onlyRequires = true/' "$ZYPP_CONF"
fi

echo "--- Apex Linux DNA Successfully Initialized! ---"
exit 0
