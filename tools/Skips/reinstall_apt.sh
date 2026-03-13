#!/bin/bash
# reinstall_apt.sh
# Reinstalls apt using dpkg (low-level package manager)
# For use on Debian/Ubuntu-based systems
# CCDC defensive script

set -euo pipefail

if [[ "$EUID" -ne 0 ]]; then
    echo "[!] This script must be run as root."
    exit 1
fi

echo "[*] Starting apt reinstallation via dpkg..."

# Step 1: Find the apt .deb package in the dpkg cache
APT_DEB=$(find /var/cache/apt/archives/ -name "apt_*.deb" 2>/dev/null | sort -V | tail -n 1)

if [[ -z "$APT_DEB" ]]; then
    echo "[*] No cached apt .deb found. Downloading apt package via dpkg + curl/wget..."

    # Get the apt package version and download URL from dpkg status
    APT_VERSION=$(dpkg-query -W -f='${Version}' apt 2>/dev/null || true)

    if [[ -z "$APT_VERSION" ]]; then
        echo "[!] Cannot determine apt version from dpkg. Attempting blind reinstall..."
        # Use dpkg to extract and reinstall apt from the existing binary if possible
        dpkg --configure -a
        dpkg -i --force-reinstall /var/cache/apt/archives/apt_*.deb 2>/dev/null || true
    fi

    # Attempt download using wget or curl (whichever is available)
    ARCH=$(dpkg --print-architecture)
    APT_PKG_NAME="apt_${APT_VERSION}_${ARCH}.deb"
    DOWNLOAD_DIR="/tmp/apt_reinstall"
    mkdir -p "$DOWNLOAD_DIR"

    # Try to pull from a Debian/Ubuntu mirror directly via wget or curl
    MIRRORS=(
        "http://archive.ubuntu.com/ubuntu/pool/main/a/apt/"
        "http://deb.debian.org/debian/pool/main/a/apt/"
    )

    DOWNLOADED=0
    for MIRROR in "${MIRRORS[@]}"; do
        echo "[*] Trying mirror: $MIRROR"
        if command -v wget &>/dev/null; then
            wget -q --tries=2 --timeout=10 -P "$DOWNLOAD_DIR" "${MIRROR}${APT_PKG_NAME}" && DOWNLOADED=1 && break
        elif command -v curl &>/dev/null; then
            curl -fsSL --max-time 10 -o "${DOWNLOAD_DIR}/${APT_PKG_NAME}" "${MIRROR}${APT_PKG_NAME}" && DOWNLOADED=1 && break
        fi
    done

    if [[ "$DOWNLOADED" -eq 1 ]]; then
        APT_DEB="${DOWNLOAD_DIR}/${APT_PKG_NAME}"
    else
        echo "[!] Could not download apt package. Falling back to dpkg --configure -a..."
        dpkg --configure -a
        echo "[*] Done. Please verify apt functionality manually."
        exit 0
    fi
fi

echo "[*] Using package: $APT_DEB"

# Step 2: Reinstall apt using dpkg directly
echo "[*] Reinstalling apt with dpkg..."
dpkg -i --force-reinstreq --force-overwrite "$APT_DEB"

# Step 3: Reconfigure any partially configured packages
echo "[*] Reconfiguring any broken packages..."
dpkg --configure -a

# Step 4: Verify apt is functional
echo "[*] Verifying apt..."
if apt-get check &>/dev/null; then
    echo "[+] apt reinstallation successful and functional."
else
    echo "[!] apt check reported issues. Manual inspection may be needed."
fi

# Step 5: Restore apt sources if missing
if [[ ! -s /etc/apt/sources.list ]]; then
    echo "[!] /etc/apt/sources.list is empty or missing!"
    echo "[*] Detecting OS to restore default sources..."
    if grep -qi "ubuntu" /etc/os-release 2>/dev/null; then
        CODENAME=$(grep VERSION_CODENAME /etc/os-release | cut -d= -f2)
        cat > /etc/apt/sources.list <<EOF
deb http://archive.ubuntu.com/ubuntu ${CODENAME} main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu ${CODENAME}-updates main restricted universe multiverse
deb http://security.ubuntu.com/ubuntu ${CODENAME}-security main restricted universe multiverse
EOF
        echo "[+] Restored Ubuntu sources.list for ${CODENAME}."
    elif grep -qi "debian" /etc/os-release 2>/dev/null; then
        CODENAME=$(grep VERSION_CODENAME /etc/os-release | cut -d= -f2)
        cat > /etc/apt/sources.list <<EOF
deb http://deb.debian.org/debian ${CODENAME} main contrib non-free
deb http://deb.debian.org/debian ${CODENAME}-updates main contrib non-free
deb http://security.debian.org/debian-security ${CODENAME}-security main contrib non-free
EOF
        echo "[+] Restored Debian sources.list for ${CODENAME}."
    else
        echo "[!] Unknown distro. Please manually restore /etc/apt/sources.list."
    fi
fi

echo "[*] apt reinstall script complete."
