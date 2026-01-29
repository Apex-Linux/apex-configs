Name:       apex-release
Version:    2026.1
Release:    2%{?dist}
Summary:    Apex Linux Release Files & Repos
License:    GPLv3
URL:        https://github.com/Apex-Linux/apex-configs
BuildArch:  noarch
Requires:   fedora-repos

Obsoletes:  fedora-release-identity-basic < 44
Obsoletes:  fedora-release-common < 44
Provides:   system-release(2026)
Provides:   system-release-product

%description
Defines Apex Linux identity and repository configuration.

%prep
# No setup needed

%build
# No build needed

%install
mkdir -p %{buildroot}/etc
mkdir -p %{buildroot}/etc/yum.repos.d

# 1. OS Release Info (The Text displayed in Settings)
cat > %{buildroot}/etc/os-release << EOF
NAME="Apex Linux"
VERSION="2026"
ID=apex
ID_LIKE=fedora
VERSION_ID=43
PRETTY_NAME="Apex Linux (KDE)"
ANSI_COLOR="0;36"
CPE_NAME="cpe:/o:apex:linux:2026"
HOME_URL="https://apexlinux.org"
EOF

# 2. Apex Repo (Your COPR Project)
cat > %{buildroot}/etc/yum.repos.d/apex.repo << EOF
[apex-core]
name=Apex Linux Core
baseurl=https://download.copr.fedorainfracloud.org/results/ackerman/apex-core/fedora-\$releasever-\$basearch/
enabled=1
gpgcheck=0
skip_if_unavailable=0
metadata_expire=1h
type=rpm-md
EOF

%files
/etc/os-release
/etc/yum.repos.d/apex.repo

%changelog
* Fri Jan 30 2026 Apex Maintainer <dev@apexlinux.org> - 2026.1-2
- Fixed unversioned obsoletes warning
* Fri Jan 30 2026 Apex Maintainer <dev@apexlinux.org> - 2026.1-1
- Initial release for Fedora 43
