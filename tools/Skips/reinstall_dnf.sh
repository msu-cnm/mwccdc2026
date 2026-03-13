#!/bin/bash
# reinstall_dnf.sh
# Reinstalls dnf using rpm (low-level package manager)
# For use on RHEL/CentOS/Fedora/Rocky/AlmaLinux-based systems
# CCDC defensive script

set -euo pipefail

if [[ "$EUID" -ne 0 ]]; then
    echo "[!] This script must be run as root."
    exit 1
fi

echo "[*] Starting dnf reinstallation via rpm..."

# Step 1: Detect OS and version
OS_ID=$(grep -oP '(?<=^ID=).+' /etc/os-release | tr -d '"' 2>/dev/null || echo "unknown")
OS_VERSION=$(grep -oP '(?<=^VERSION_ID=).+' /etc/os-release | tr -d '"' 2>/dev/null || echo "unknown")
ARCH=$(uname -m)

echo "[*] Detected OS: $OS_ID $OS_VERSION ($ARCH)"

# Step 2: Check if rpm is available (it's the low-level tool we rely on)
if ! command -v rpm &>/dev/null; then
    echo "[!] rpm not found. Cannot proceed — rpm is required as the low-level package manager."
    exit 1
fi

# Step 3: Check if dnf RPM is cached locally
DNF_RPM=$(rpm -q --queryformat '%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}.rpm\n' dnf 2>/dev/null | head -n1 || true)
CACHED_RPM=$(find /var/cache/dnf/ /var/cache/yum/ -name "dnf-*.rpm" 2>/dev/null | sort -V | tail -n1 || true)

if [[ -n "$CACHED_RPM" ]]; then
    echo "[*] Found cached dnf RPM: $CACHED_RPM"
    RPM_TO_INSTALL="$CACHED_RPM"
else
    echo "[*] No cached dnf RPM found. Attempting to download..."

    DOWNLOAD_DIR="/tmp/dnf_reinstall"
    mkdir -p "$DOWNLOAD_DIR"

    # Define mirror base URLs per distro
    case "$OS_ID" in
        fedora)
            MIRROR="https://dl.fedoraproject.org/pub/fedora/linux/releases/${OS_VERSION}/Everything/${ARCH}/os/Packages/d/"
            ;;
        centos)
            MIRROR="https://mirror.centos.org/centos/${OS_VERSION}/BaseOS/${ARCH}/os/Packages/"
            ;;
        rhel | rocky | almalinux)
            MIRROR="https://dl.rockylinux.org/pub/rocky/${OS_VERSION}/BaseOS/${ARCH}/os/Packages/d/"
            ;;
        *)
            MIRROR=""
            echo "[!] Unknown distro: $OS_ID. Will attempt rpm --reinstall from rpmdb only."
            ;;
    esac

    DOWNLOADED=0
    if [[ -n "$MIRROR" ]]; then
        echo "[*] Trying mirror: $MIRROR"

        # Get the exact RPM filename
        if command -v curl &>/dev/null; then
            LISTING=$(curl -fsSL --max-time 10 "$MIRROR" 2>/dev/null || true)
        elif command -v wget &>/dev/null; then
            LISTING=$(wget -q --timeout=10 -O - "$MIRROR" 2>/dev/null || true)
        fi

        RPM_FILENAME=$(echo "$LISTING" | grep -oP 'dnf-[0-9][^"]+\.rpm' | grep -v "plugin\|conf\|data" | sort -V | tail -n1 || true)

        if [[ -n "$RPM_FILENAME" ]]; then
            FULL_URL="${MIRROR}${RPM_FILENAME}"
            echo "[*] Downloading: $FULL_URL"
            if command -v curl &>/dev/null; then
                curl -fsSL --max-time 30 -o "${DOWNLOAD_DIR}/${RPM_FILENAME}" "$FULL_URL" && DOWNLOADED=1
            elif command -v wget &>/dev/null; then
                wget -q --timeout=30 -O "${DOWNLOAD_DIR}/${RPM_FILENAME}" "$FULL_URL" && DOWNLOADED=1
            fi
            [[ "$DOWNLOADED" -eq 1 ]] && RPM_TO_INSTALL="${DOWNLOAD_DIR}/${RPM_FILENAME}"
        fi
    fi

    if [[ "$DOWNLOADED" -eq 0 ]]; then
        echo "[*] Could not download RPM. Attempting rpm --reinstall from installed package database..."
        if rpm -q dnf &>/dev/null; then
            rpm -e --nodeps dnf 2>/dev/null || true
            # Re-install using yum if available as fallback
            if command -v yum &>/dev/null; then
                echo "[*] Falling back to yum to reinstall dnf..."
                yum install -y dnf
                echo "[+] dnf reinstalled via yum."
            else
                echo "[!] No fallback available. dnf could not be reinstalled automatically."
            fi
        else
            echo "[!] dnf is not registered in the rpm database. Manual intervention required."
        fi
        exit 0
    fi
fi

# Step 4: Reinstall dnf using rpm
echo "[*] Reinstalling dnf with rpm..."
rpm -Uvh --force --nodeps "$RPM_TO_INSTALL"

# Step 5: Reinstall dnf dependencies if needed
echo "[*] Attempting to fix any missing dependencies via rpm..."
rpm --rebuilddb

# Step 6: Verify dnf works
echo "[*] Verifying dnf..."
if dnf --version &>/dev/null; then
    echo "[+] dnf reinstallation successful!"
    dnf --version
else
    echo "[!] dnf binary not responding correctly after reinstall. Manual inspection required."
fi

# Step 7: Check/restore repo files if missing
REPO_DIR="/etc/yum.repos.d"
if [[ -z "$(ls -A $REPO_DIR 2>/dev/null)" ]]; then
    echo "[!] No repo files found in $REPO_DIR!"
    echo "[*] Attempting to restore default repos..."
    case "$OS_ID" in
        fedora)
            dnf install -y fedora-repos --releasever="$OS_VERSION" 2>/dev/null || \
            rpm -Uvh "https://dl.fedoraproject.org/pub/fedora/linux/releases/${OS_VERSION}/Everything/${ARCH}/os/Packages/f/fedora-repos-${OS_VERSION}-1.noarch.rpm" 2>/dev/null || \
            echo "[!] Could not restore Fedora repos automatically."
            ;;
        centos | rhel | rocky | almalinux)
            echo "[!] Please manually restore repo files to $REPO_DIR."
            echo "    Example: rpm -Uvh https://dl.rockylinux.org/pub/rocky/.../rocky-repos-*.rpm"
            ;;
        *)
            echo "[!] Unknown distro. Manually restore repo files to $REPO_DIR."
            ;;
    esac
else
    echo "[*] Repo files present in $REPO_DIR — no restoration needed."
fi

echo "[*] dnf reinstall script complete."
