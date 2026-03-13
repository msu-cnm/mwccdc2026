#!/bin/bash
# =============================================================================
# CCDC Mail Server Nuke Script
# Completely wipes all mail server configs and packages for a clean reinstall
# =============================================================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_banner() {
    echo -e "${RED}"
    echo "=============================================="
    echo "   CCDC Mail Server Nuke Script"
    echo "   WARNING: This will wipe ALL mail server"
    echo "   configs and packages!"
    echo "=============================================="
    echo -e "${NC}"
}

print_step() {
    echo -e "\n${GREEN}[STEP]${NC} $1"
}

print_info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# =============================================================================
# CONFIRMATION
# =============================================================================
confirm() {
    print_banner
    echo -e "${RED}This script will:${NC}"
    echo "  - Stop and disable all mail services"
    echo "  - Leave the AD domain"
    echo "  - Uninstall Postfix, Dovecot, SSSD, realmd, adcli and related packages"
    echo "  - Delete all config files for the above"
    echo "  - Reset /etc/hosts, /etc/resolv.conf, /etc/krb5.conf"
    echo "  - Reset SSH config to allow all local users"
    echo "  - Reset PAM to system defaults"
    echo ""
    echo -e "${RED}This is IRREVERSIBLE without your backup script!${NC}"
    echo ""
    read -p "Type 'NUKE' to confirm: " CONFIRM
    if [[ "$CONFIRM" != "NUKE" ]]; then
        echo -e "${GREEN}Aborted. Nothing was changed.${NC}"
        exit 0
    fi

    echo ""
    read -p "Are you absolutely sure? (y/n): " DOUBLE_CONFIRM
    if [[ "$DOUBLE_CONFIRM" != "y" && "$DOUBLE_CONFIRM" != "Y" ]]; then
        echo -e "${GREEN}Aborted. Nothing was changed.${NC}"
        exit 0
    fi
}

# =============================================================================
# STEP 1: STOP AND DISABLE SERVICES
# =============================================================================
stop_services() {
    print_step "Stopping and disabling services"

    for SVC in postfix dovecot sssd oddjobd; do
        if systemctl is-active "$SVC" &>/dev/null; then
            systemctl stop "$SVC"
            print_info "Stopped $SVC"
        fi
        if systemctl is-enabled "$SVC" &>/dev/null; then
            systemctl disable "$SVC"
            print_info "Disabled $SVC"
        fi
    done

    print_success "Services stopped and disabled"
}

# =============================================================================
# STEP 2: LEAVE THE DOMAIN
# =============================================================================
leave_domain() {
    print_step "Leaving AD domain"

    if realm list 2>/dev/null | grep -q "domain-name"; then
        DOMAIN=$(realm list | grep "domain-name" | awk '{print $2}')
        print_info "Leaving domain: $DOMAIN"
        realm leave 2>/dev/null && print_success "Left domain $DOMAIN" || print_info "Could not cleanly leave domain (may already be disconnected)"
    else
        print_info "Not currently joined to any domain — skipping"
    fi
}

# =============================================================================
# STEP 3: UNINSTALL PACKAGES
# =============================================================================
uninstall_packages() {
    print_step "Uninstalling packages"

    PACKAGES=(
        postfix
        dovecot
        dovecot-pigeonhole
        realmd
        sssd
        sssd-ad
        sssd-common
        sssd-client
        sssd-kcm
        adcli
        oddjob
        oddjob-mkhomedir
        samba-common-tools
        samba-common
        openldap-clients
        krb5-workstation
        cyrus-sasl
        cyrus-sasl-plain
        cyrus-sasl-lib
        expect
        fail2ban
    )

    for PKG in "${PACKAGES[@]}"; do
        if rpm -q "$PKG" &>/dev/null; then
            dnf remove -y "$PKG" &>/dev/null
            print_info "Removed: $PKG"
        else
            print_info "Not installed: $PKG (skipping)"
        fi
    done

    # Clean up orphaned dependencies
    print_info "Running autoremove..."
    dnf autoremove -y &>/dev/null

    print_success "Packages uninstalled"
}

# =============================================================================
# STEP 4: REMOVE CONFIG FILES AND DIRECTORIES
# =============================================================================
remove_configs() {
    print_step "Removing config files and directories"

    # Postfix
    rm -rf /etc/postfix && print_info "Removed /etc/postfix"
    rm -rf /var/spool/postfix && print_info "Removed /var/spool/postfix"
    rm -rf /var/lib/postfix && print_info "Removed /var/lib/postfix"

    # Dovecot
    rm -rf /etc/dovecot && print_info "Removed /etc/dovecot"
    rm -rf /var/lib/dovecot && print_info "Removed /var/lib/dovecot"
    rm -rf /var/run/dovecot && print_info "Removed /var/run/dovecot"

    # SSSD
    rm -rf /etc/sssd && print_info "Removed /etc/sssd"
    rm -rf /var/lib/sss && print_info "Removed /var/lib/sss"
    rm -rf /var/log/sssd && print_info "Removed /var/log/sssd"
    rm -rf /var/cache/sssd && print_info "Removed /var/cache/sssd"

    # Kerberos
    rm -f /etc/krb5.conf && print_info "Removed /etc/krb5.conf"
    rm -f /etc/krb5.keytab && print_info "Removed /etc/krb5.keytab"
    rm -rf /tmp/krb5* && print_info "Removed Kerberos temp files"

    # PAM dovecot file
    rm -f /etc/pam.d/dovecot && print_info "Removed /etc/pam.d/dovecot"

    # Samba
    rm -rf /etc/samba && print_info "Removed /etc/samba"
    rm -rf /var/lib/samba && print_info "Removed /var/lib/samba"

    # Fail2ban
    rm -rf /etc/fail2ban && print_info "Removed /etc/fail2ban"

    print_success "Config files removed"
}

# =============================================================================
# STEP 5: RESET /etc/hosts
# =============================================================================
reset_hosts() {
    print_step "Resetting /etc/hosts"

    # Remove any domain-related entries but keep localhost entries
    cp /etc/hosts /etc/hosts.nuke_backup
    grep -E "^127\.|^::1" /etc/hosts.nuke_backup > /etc/hosts
    print_info "Kept localhost entries, removed domain entries"
    print_info "Original backed up to /etc/hosts.nuke_backup"

    print_success "/etc/hosts reset"
}

# =============================================================================
# STEP 6: RESET DNS
# =============================================================================
reset_dns() {
    print_step "Resetting /etc/resolv.conf"

    echo "" > /etc/resolv.conf
    print_info "Cleared /etc/resolv.conf"

    print_success "DNS reset"
}

# =============================================================================
# STEP 7: RESET SSH CONFIG
# =============================================================================
reset_ssh() {
    print_step "Resetting SSH config"

    # Remove AllowUsers restriction
    sed -i '/^AllowUsers/d' /etc/ssh/sshd_config
    print_info "Removed AllowUsers restriction"

    # Reset PermitRootLogin to default
    sed -i 's/^PermitRootLogin no/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
    print_info "Reset PermitRootLogin to prohibit-password"

    # Reset PermitEmptyPasswords
    sed -i 's/^PermitEmptyPasswords no/#PermitEmptyPasswords no/' /etc/ssh/sshd_config
    print_info "Reset PermitEmptyPasswords"

    systemctl restart sshd
    print_success "SSH config reset"
}

# =============================================================================
# STEP 8: RESET PAM
# =============================================================================
reset_pam() {
    print_step "Resetting PAM to system defaults"

    authselect select sssd with-mkhomedir --force 2>/dev/null || \
    authselect select minimal --force 2>/dev/null || \
    print_info "Could not reset authselect — may need manual reset"

    print_success "PAM reset"
}

# =============================================================================
# STEP 9: RESET HOSTNAME (OPTIONAL)
# =============================================================================
reset_hostname() {
    print_step "Hostname reset"

    CURRENT=$(hostname)
    print_info "Current hostname: $CURRENT"
    read -p "Reset hostname? Enter new hostname or press ENTER to keep current: " NEW_HOSTNAME

    if [ -n "$NEW_HOSTNAME" ]; then
        hostnamectl set-hostname "$NEW_HOSTNAME"
        print_success "Hostname set to $NEW_HOSTNAME"
    else
        print_info "Hostname unchanged: $CURRENT"
    fi
}

# =============================================================================
# STEP 10: CLEAN UP SYSTEMD
# =============================================================================
cleanup_systemd() {
    print_step "Cleaning up systemd"

    systemctl daemon-reload
    systemctl reset-failed 2>/dev/null || true
    print_success "Systemd cleaned up"
}

# =============================================================================
# VERIFY
# =============================================================================
verify_nuke() {
    print_step "Verifying nuke"

    echo ""
    rpm -q postfix &>/dev/null && \
        echo -e "  ${RED}[FAILED]${NC} Postfix still installed" || \
        echo -e "  ${GREEN}[OK]${NC}     Postfix removed"

    rpm -q dovecot &>/dev/null && \
        echo -e "  ${RED}[FAILED]${NC} Dovecot still installed" || \
        echo -e "  ${GREEN}[OK]${NC}     Dovecot removed"

    rpm -q sssd &>/dev/null && \
        echo -e "  ${RED}[FAILED]${NC} SSSD still installed" || \
        echo -e "  ${GREEN}[OK]${NC}     SSSD removed"

    realm list 2>/dev/null | grep -q "domain-name" && \
        echo -e "  ${RED}[FAILED]${NC} Still joined to domain" || \
        echo -e "  ${GREEN}[OK]${NC}     Not joined to any domain"

    [ -d /etc/postfix ] && \
        echo -e "  ${RED}[FAILED]${NC} /etc/postfix still exists" || \
        echo -e "  ${GREEN}[OK]${NC}     /etc/postfix removed"

    [ -d /etc/dovecot ] && \
        echo -e "  ${RED}[FAILED]${NC} /etc/dovecot still exists" || \
        echo -e "  ${GREEN}[OK]${NC}     /etc/dovecot removed"

    [ -d /etc/sssd ] && \
        echo -e "  ${RED}[FAILED]${NC} /etc/sssd still exists" || \
        echo -e "  ${GREEN}[OK]${NC}     /etc/sssd removed"

    echo ""
    echo -e "${BLUE}=============================================="
    echo "Nuke complete! Server is ready for a fresh"
    echo "install. Run mail_setup.sh to reconfigure."
    echo -e "==============================================\n${NC}"
}

# =============================================================================
# MAIN
# =============================================================================
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}[ERROR]${NC} This script must be run as root (sudo)."
    exit 1
fi

confirm
stop_services
leave_domain
uninstall_packages
remove_configs
reset_hosts
reset_dns
reset_ssh
reset_pam
reset_hostname
cleanup_systemd
verify_nuke
