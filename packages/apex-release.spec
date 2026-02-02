Name:           apex-release
Version:        2026.1
Release:        5%{?dist}
Summary:        Apex Linux Release Files & Repos
License:        GPLv3
URL:            https://github.com/Apex-Linux/apex-configs
BuildArch:      noarch

# DEPENDENCIES
Requires:       fedora-repos
Requires:       coreutils

# IDENTITY OVERRIDES (The "Distro" Magic)
Provides:       system-release = 43
Provides:       system-release(2026)
Provides:       generic-release = 43
Provides:       fedora-release-identity = 43
Provides:       fedora-release-common = 43

# REPLACE FEDORA IDENTITY
# We use 'Conflicts' to ensure we don't accidentally coexist with Fedora branding
Conflicts:      fedora-release-identity
Conflicts:      generic-release

%description
Defines Apex Linux identity, release files, and default repository configuration.
This package connects the system to the Apex Core COPR for updates.

%prep
# No setup needed

%build
# No build needed

%install
mkdir -p %{buildroot}/etc
mkdir -p %{buildroot}/etc/yum.repos.d
mkdir -p %{buildroot}/usr/lib

# 1. OS Release Info (The "ID Card")
# We verify this writes to BOTH /etc/os-release and /usr/lib/os-release for compatibility
cat > %{buildroot}/etc/os-release << EOF
NAME="Apex Linux"
VERSION="2026.1"
ID=apex
ID_LIKE="fedora"
VERSION_ID=43
PRETTY_NAME="Apex Linux 2026.1 (KDE)"
ANSI_COLOR="0;36"
CPE_NAME="cpe:/o:apex:linux:2026"
HOME_URL="https://apexlinux.org"
SUPPORT_URL="https://github.com/Apex-Linux"
BUG_REPORT_URL="https://github.com/Apex-Linux/apex-configs/issues"
EOF

# Symlink for compatibility
ln -s ../etc/os-release %{buildroot}/usr/lib/os-release

# 2. Apex Repo (The "Lifeline")
# Note: Replaced 'ackerman' with 'Apex-Linux' if that is your COPR group/user
cat > %{buildroot}/etc/yum.repos.d/apex.repo << EOF
[apex-core]
name=Apex Linux Core
baseurl=https://download.copr.fedorainfracloud.org/results/ackerman/apex-core/fedora-\$releasever-\$basearch/
enabled=1
# Ideally enable GPG check if you have the key URL, otherwise 0 is fine for alpha
gpgcheck=0
skip_if_unavailable=0
metadata_expire=1h
type=rpm-md
priority=90
EOF

# 3. Issue File (Login Screen Text)
echo "Apex Linux 2026.1 \n \l" > %{buildroot}/etc/issue
echo "Apex Linux 2026.1" > %{buildroot}/etc/issue.net

%files
%config(noreplace) /etc/os-release
/usr/lib/os-release
%config(noreplace) /etc/yum.repos.d/apex.repo
%config(noreplace) /etc/issue
%config(noreplace) /etc/issue.net

%changelog
* Mon Feb 02 2026 Apex Maintainer <dev@apexlinux.org> - 2026.1-5
- Added priority=90 to repo
- Added /usr/lib/os-release symlink for systemd compatibility
* Fri Jan 30 2026 Apex Maintainer <dev@apexlinux.org> - 2026.1-4
- Added Provides to fix file conflict with generic-release
