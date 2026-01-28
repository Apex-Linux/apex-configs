#!/usr/bin/env bash
# Apex Linux Phase 4: Final Hardened & Self-Auditing Configuration
set -euo pipefail

# --- Safety Check: Ensure Root ---
if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: Apex DNA initialization must be run as root!" >&2
    exit 1
fi

LIVE_USER="apex"
LIVE_PASS="" # Production: Locked account (SDDM autologin is used)

echo "--- [1/5] Initializing User & Group Security ---"

# Ensure the shadow group exists for unix_chkpwd (fixes log warnings)
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

# --- Fix root account ---
echo "root:linux" | chpasswd
echo "  [OK] Root password set to 'linux'."

if ! id "$LIVE_USER" &>/dev/null; then
    useradd -m -s /bin/bash -G wheel,video,audio,users,render "$LIVE_USER"
    [ -n "$LIVE_PASS" ] && echo "$LIVE_USER:$LIVE_PASS" | chpasswd || passwd -l "$LIVE_USER"
    
    # Secure Sudoers (Mode 0440 is mandatory for sudo to function)
    cat > /etc/sudoers.d/apex <<'EOF'
# WARNING: This configuration is for Apex Live Media ONLY.
# Passwordless sudo is enabled for the live user experience.
apex ALL=(ALL) NOPASSWD: ALL
EOF
    chmod 0440 /etc/sudoers.d/apex
    echo "  [OK] Live user '$LIVE_USER' initialized with 0440 sudoers."

    # Container Support: Idempotent subuid/subgid mapping for Podman
    touch /etc/subuid /etc/subgid
    chmod 0644 /etc/subuid /etc/subgid
    grep -q "^${LIVE_USER}:" /etc/subuid || echo "${LIVE_USER}:100000:65536" >> /etc/subuid
    grep -q "^${LIVE_USER}:" /etc/subgid || echo "${LIVE_USER}:100000:65536" >> /etc/subgid
    echo "  [OK] Rootless container mappings applied."
else
    echo "  [SKIP] User '$LIVE_USER' already exists."
fi

echo "--- [2/5] Configuring Services & Polkit ---"

# Fix Polkit directory error seen in build logs
mkdir -p /etc/polkit-1/rules.d/
chmod 700 /etc/polkit-1/rules.d/
chown polkitd:root /etc/polkit-1/rules.d/ 2>/dev/null || true
echo "  [OK] Polkit directory structure pre-initialized."

systemctl enable NetworkManager 2>/dev/null || true
systemctl enable sddm 2>/dev/null || true

# Bulletproof Unit Path Check (Covers /usr/lib and /lib)
for possible in /usr/lib/systemd/system/sddm.service /lib/systemd/system/sddm.service; do
  if [ -f "$possible" ]; then
    mkdir -p /etc/systemd/system/graphical.target.wants
    ln -sf "$possible" /etc/systemd/system/display-manager.service
    ln -sf "$possible" /etc/systemd/system/graphical.target.wants/sddm.service
    echo "  [OK] Manual SDDM symlinks created from $possible"
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
echo "  [INFO] Target Session: $SESSION"

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
echo "  [OK] Branding and hostname applied."

echo "--- [5/5] Final Hardware & System Tweaks ---"
for bin in /usr/bin/newuidmap /usr/bin/newgidmap; do
    if [ -x "$bin" ]; then
        chown root:root "$bin"
        if command -v setcap >/dev/null 2>&1; then
            [[ "$bin" == *newuidmap ]] && setcap cap_setuid+ep "$bin" || setcap cap_setgid+ep "$bin"
            echo "  [CAPS] Set capabilities for $(basename "$bin")"
        else
            chmod 4755 "$bin"
            echo "  [SUID] Set SUID bit for $(basename "$bin")"
        fi
    fi
done

systemctl set-default graphical.target
[ -x /usr/bin/systemd-hwdb ] && systemd-hwdb update || true

# Safe Zypper optimization
ZYPP_CONF="/etc/zypp/zypp.conf"
if [ -f "$ZYPP_CONF" ]; then
    sed -i 's/^# solver.onlyRequires.*/solver.onlyRequires = true/' "$ZYPP_CONF"
    sed -i 's/^solver.onlyRequires.*/solver.onlyRequires = true/' "$ZYPP_CONF"
fi

echo "--- Apex Linux DNA Successfully Initialized! ---"
exit 0
