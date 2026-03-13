#!/bin/bash
# =============================================================================
# CCDC Mail Server Setup Script
# Installs and configures Postfix + Dovecot with Active Directory authentication
# For use on Fedora servers
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_banner() {
    echo -e "${BLUE}"
    echo "=============================================="
    echo "   CCDC Mail Server Setup Script"
    echo "   Postfix + Dovecot + Active Directory"
    echo "=============================================="
    echo -e "${NC}"
}

print_step() {
    echo -e "\n${GREEN}[STEP]${NC} $1"
}

print_info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# =============================================================================
# GATHER INPUT
# =============================================================================
gather_input() {
    print_banner
    echo -e "${YELLOW}Please provide the following information:${NC}\n"

    # Hostname
    read -p "Enter the mail server hostname (e.g. mail): " MAIL_HOSTNAME
    while [[ -z "$MAIL_HOSTNAME" ]]; do
        print_error "Hostname cannot be empty."
        read -p "Enter the mail server hostname (e.g. mail): " MAIL_HOSTNAME
    done

    # Domain name
    read -p "Enter the AD domain name (e.g. feralnet.local): " DOMAIN_NAME
    while [[ -z "$DOMAIN_NAME" ]]; do
        print_error "Domain name cannot be empty."
        read -p "Enter the AD domain name (e.g. feralnet.local): " DOMAIN_NAME
    done

    # Uppercase realm
    REALM=$(echo "$DOMAIN_NAME" | tr '[:lower:]' '[:upper:]')

    # FQDN
    FQDN="${MAIL_HOSTNAME}.${DOMAIN_NAME}"

    # DC IP address
    read -p "Enter the Domain Controller/DNS IP address: " DC_IP
    while [[ -z "$DC_IP" ]]; do
        print_error "DC IP cannot be empty."
        read -p "Enter the Domain Controller/DNS IP address: " DC_IP
    done

    # DC hostname
    read -p "Enter the Domain Controller hostname (e.g. win2k22): " DC_HOSTNAME
    while [[ -z "$DC_HOSTNAME" ]]; do
        print_error "DC hostname cannot be empty."
        read -p "Enter the Domain Controller hostname (e.g. win2k22): " DC_HOSTNAME
    done

    # AD Administrator password
    read -sp "Enter the AD Administrator password: " AD_ADMIN_PASS
    echo ""
    while [[ -z "$AD_ADMIN_PASS" ]]; do
        print_error "Password cannot be empty."
        read -sp "Enter the AD Administrator password: " AD_ADMIN_PASS
        echo ""
    done

    # Local admin user
    read -p "Enter the local Linux admin username (e.g. cnm): " LOCAL_USER
    while [[ -z "$LOCAL_USER" ]]; do
        print_error "Local username cannot be empty."
        read -p "Enter the local Linux admin username: " LOCAL_USER
    done

    echo ""
    echo -e "${BLUE}=============================================="
    echo "Configuration Summary:"
    echo "  Mail Hostname : $MAIL_HOSTNAME"
    echo "  Domain        : $DOMAIN_NAME"
    echo "  Realm         : $REALM"
    echo "  FQDN          : $FQDN"
    echo "  DC IP         : $DC_IP"
    echo "  DC Hostname   : $DC_HOSTNAME"
    echo "  Local User    : $LOCAL_USER"
    echo "  SSH Access    : sysadmin only"
    echo -e "==============================================\n${NC}"

    read -p "Proceed with these settings? (y/n): " CONFIRM
    if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
        print_error "Aborted by user."
        exit 1
    fi
}

# =============================================================================
# STEP 1: SET HOSTNAME
# =============================================================================
set_hostname() {
    print_step "Setting hostname to $FQDN"
    hostnamectl set-hostname "$FQDN"
    print_success "Hostname set to $FQDN"
}

# =============================================================================
# STEP 2: CONFIGURE /etc/hosts
# =============================================================================
configure_hosts() {
    print_step "Configuring /etc/hosts"

    # Get current machine IP
    MACHINE_IP=$(hostname -I | awk '{print $1}')

    # Add DC entry if not already present
    if ! grep -q "$DC_IP" /etc/hosts; then
        echo "$DC_IP   ${DC_HOSTNAME}.${DOMAIN_NAME} ${DC_HOSTNAME} ${REALM}" >> /etc/hosts
        print_info "Added DC entry to /etc/hosts"
    else
        print_info "DC entry already exists in /etc/hosts"
    fi

    # Add own FQDN if not present
    if ! grep -q "$FQDN" /etc/hosts; then
        echo "$MACHINE_IP   $FQDN $MAIL_HOSTNAME" >> /etc/hosts
        print_info "Added mail server FQDN to /etc/hosts"
    fi

    print_success "/etc/hosts configured"
}

# =============================================================================
# STEP 3: CONFIGURE DNS
# =============================================================================
configure_dns() {
    print_step "Configuring DNS to point at DC ($DC_IP)"
    echo "nameserver $DC_IP" > /etc/resolv.conf
    print_success "DNS configured"
}

# =============================================================================
# STEP 4: INSTALL PACKAGES
# =============================================================================
install_packages() {
    print_step "Installing required packages"
    dnf install -y \
        postfix \
        dovecot \
        realmd \
        sssd \
        sssd-ad \
        adcli \
        oddjob \
        oddjob-mkhomedir \
        samba-common-tools \
        openldap-clients \
        krb5-workstation \
        authselect \
        cyrus-sasl \
        cyrus-sasl-plain \
        telnet
    print_success "Packages installed"
}

# =============================================================================
# STEP 5: CONFIGURE KERBEROS
# =============================================================================
configure_kerberos() {
    print_step "Configuring Kerberos (/etc/krb5.conf)"
    cat > /etc/krb5.conf <<EOF
[libdefaults]
    default_realm = ${REALM}
    dns_lookup_realm = false
    dns_lookup_kdc = false
    ticket_lifetime = 24h
    renew_lifetime = 7d
    forwardable = true

[realms]
    ${REALM} = {
        kdc = ${DC_IP}
        admin_server = ${DC_IP}
    }

[domain_realm]
    .${DOMAIN_NAME} = ${REALM}
    ${DOMAIN_NAME} = ${REALM}
EOF
    print_success "Kerberos configured"
}

# =============================================================================
# STEP 6: JOIN DOMAIN
# =============================================================================
join_domain() {
    print_step "Joining domain $DOMAIN_NAME"

    # Check if already joined
    if realm list | grep -q "$DOMAIN_NAME"; then
        print_info "Already joined to $DOMAIN_NAME — skipping"
        return
    fi

    echo "$AD_ADMIN_PASS" | realm join "$DC_IP" -U Administrator --stdin
    if [ $? -eq 0 ]; then
        print_success "Successfully joined domain $DOMAIN_NAME"
    else
        print_error "Domain join failed. Check DC IP, password, and network connectivity."
        exit 1
    fi
}

# =============================================================================
# STEP 7: CONFIGURE SSSD
# =============================================================================
configure_sssd() {
    print_step "Configuring SSSD"
    cat > /etc/sssd/sssd.conf <<EOF
[sssd]
domains = ${DOMAIN_NAME}
config_file_version = 2
services = nss, pam

[domain/${DOMAIN_NAME}]
default_shell = /bin/bash
ad_server = ${DC_HOSTNAME}.${DOMAIN_NAME}
krb5_store_password_if_offline = True
cache_credentials = True
krb5_realm = ${REALM}
realmd_tags = manages-system joined-with-adcli
id_provider = ad
fallback_homedir = /home/%u@%d
ad_domain = ${DOMAIN_NAME}
use_fully_qualified_names = True
ldap_id_mapping = True
access_provider = permit
dns_discovery_domain = ${DOMAIN_NAME}
EOF

    chmod 600 /etc/sssd/sssd.conf
    print_success "SSSD configured"
}

# =============================================================================
# STEP 8: CONFIGURE AUTHSELECT
# =============================================================================
configure_authselect() {
    print_step "Configuring authselect for SSSD"
    authselect select sssd with-mkhomedir --force
    print_success "Authselect configured"
}

# =============================================================================
# STEP 9: CONFIGURE PAM FOR DOVECOT
# =============================================================================
configure_pam() {
    print_step "Configuring PAM for Dovecot"
    cat > /etc/pam.d/dovecot <<EOF
#%PAM-1.0
auth        required    pam_sss.so
account     sufficient  pam_sss.so
account     required    pam_permit.so
session     required    pam_sss.so
session     optional    pam_mkhomedir.so
EOF
    print_success "PAM configured for Dovecot"
}

# =============================================================================
# STEP 10: CONFIGURE POSTFIX
# =============================================================================
configure_postfix() {
    print_step "Configuring Postfix"
    cat > /etc/postfix/main.cf <<EOF
# Basic Settings
myhostname = ${FQDN}
mydomain = ${DOMAIN_NAME}
myorigin = \$mydomain
inet_interfaces = all
mydestination = \$myhostname, localhost.\$mydomain, \$mydomain

# Network Settings
mynetworks = 127.0.0.0/8

# Mailbox Settings
home_mailbox = Maildir/

# SASL Authentication (Dovecot)
smtpd_sasl_type = dovecot
smtpd_sasl_path = private/auth
smtpd_sasl_auth_enable = yes
smtpd_sasl_security_options = noanonymous
smtpd_sasl_local_domain = \$myhostname

# TLS Settings
smtpd_use_tls = yes
smtpd_tls_security_level = may
smtp_tls_security_level = may

# Restrictions
smtpd_recipient_restrictions =
    permit_sasl_authenticated,
    permit_mynetworks,
    reject_unauth_destination
EOF
    print_success "Postfix configured"
}

# =============================================================================
# STEP 11: CONFIGURE DOVECOT
# =============================================================================
configure_dovecot() {
    print_step "Configuring Dovecot"

    # Main config - enable POP3
    sed -i 's/^#protocols.*/protocols = pop3/' /etc/dovecot/dovecot.conf
    if ! grep -q "^protocols" /etc/dovecot/dovecot.conf; then
        echo "protocols = pop3" >> /etc/dovecot/dovecot.conf
    fi

    # 10-auth.conf - use PAM via system-auth
    cat > /etc/dovecot/conf.d/10-auth.conf <<EOF
disable_plaintext_auth = yes
auth_mechanisms = plain login
!include auth-pam.conf.ext
EOF

    # auth-pam.conf.ext - point to system-auth
    cat > /etc/dovecot/conf.d/auth-pam.conf.ext <<EOF
passdb {
  driver = pam
  args = system-auth
}

userdb {
  driver = passwd
}
EOF

    # 10-mail.conf - Maildir format
    sed -i 's|^#mail_location.*|mail_location = maildir:~/Maildir|' /etc/dovecot/conf.d/10-mail.conf
    if ! grep -q "^mail_location" /etc/dovecot/conf.d/10-mail.conf; then
        echo "mail_location = maildir:~/Maildir" >> /etc/dovecot/conf.d/10-mail.conf
    fi

    # 10-master.conf - Dovecot SASL socket for Postfix
    # Add unix_listener for Postfix if not already present
    if ! grep -q "postfix/private/auth" /etc/dovecot/conf.d/10-master.conf; then
        cat >> /etc/dovecot/conf.d/10-master.conf <<EOF

service auth {
  unix_listener /var/spool/postfix/private/auth {
    mode = 0660
    user = postfix
    group = postfix
  }
}
EOF
    fi

    # 20-pop3.conf - POP3 settings (without deprecated pop3_uidl_format)
    cat > /etc/dovecot/conf.d/20-pop3.conf <<EOF
protocol pop3 {
  mail_max_userip_connections = 10
  pop3_logout_format = top=%t/%p, retr=%r/%b, del=%d/%m, size=%s
  pop3_client_workarounds = outlook-no-nuls oe-ns-eoh
}
EOF

    # 10-ssl.conf - keep ssl = required for security
    if grep -q "^ssl = yes" /etc/dovecot/conf.d/10-ssl.conf; then
        sed -i 's/^ssl = yes/ssl = required/' /etc/dovecot/conf.d/10-ssl.conf
    fi
    print_info "SSL set to required in Dovecot"

    print_success "Dovecot configured"
}

# =============================================================================
# STEP 12: RESTRICT SSH TO SYSADMIN ONLY
# =============================================================================
restrict_ssh() {
    print_step "Restricting SSH access to sysadmin only"

    # Remove any existing AllowUsers line and replace with sysadmin only
    if grep -q "^AllowUsers" /etc/ssh/sshd_config; then
        sed -i "s/^AllowUsers.*/AllowUsers sysadmin/" /etc/ssh/sshd_config
    else
        echo "AllowUsers sysadmin" >> /etc/ssh/sshd_config
    fi

    # Also harden SSH while we're here
    # Disable root login
    sed -i 's/^#PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
    if ! grep -q "^PermitRootLogin" /etc/ssh/sshd_config; then
        echo "PermitRootLogin no" >> /etc/ssh/sshd_config
    fi

    # Disable empty passwords
    sed -i 's/^#PermitEmptyPasswords.*/PermitEmptyPasswords no/' /etc/ssh/sshd_config
    if ! grep -q "^PermitEmptyPasswords" /etc/ssh/sshd_config; then
        echo "PermitEmptyPasswords no" >> /etc/ssh/sshd_config
    fi

    systemctl restart sshd
    print_success "SSH restricted — only sysadmin can login, root login disabled"
}

# =============================================================================
# STEP 13: ENABLE AND START SERVICES
# =============================================================================
start_services() {
    print_step "Enabling and starting services"

    # Clear SSSD cache and restart
    sss_cache -E 2>/dev/null || true
    systemctl enable --now sssd
    systemctl restart sssd

    # Enable and start Postfix
    systemctl enable --now postfix
    systemctl restart postfix

    # Enable and start Dovecot
    systemctl enable --now dovecot
    systemctl restart dovecot

    print_success "All services started"
}

# =============================================================================
# STEP 14: VERIFY SETUP
# =============================================================================
verify_setup() {
    print_step "Verifying setup"

    echo ""
    print_info "Checking SSSD status..."
    systemctl is-active sssd && print_success "SSSD is running" || print_error "SSSD is NOT running"

    print_info "Checking Postfix status..."
    systemctl is-active postfix && print_success "Postfix is running" || print_error "Postfix is NOT running"

    print_info "Checking Dovecot status..."
    systemctl is-active dovecot && print_success "Dovecot is running" || print_error "Dovecot is NOT running"

    print_info "Checking domain join..."
    realm list | grep -q "$DOMAIN_NAME" && print_success "Domain join confirmed" || print_error "Domain join NOT confirmed"

    print_info "Testing AD user lookup (Administrator)..."
    id "administrator@${DOMAIN_NAME}" &>/dev/null && print_success "AD user lookup working" || print_error "AD user lookup FAILED"

    echo ""
    echo -e "${BLUE}=============================================="
    echo "Setup Complete!"
    echo ""
    echo "Test POP3 authentication with:"
    echo "  telnet $FQDN 110"
    echo "  USER administrator@${DOMAIN_NAME}"
    echo "  PASS <password>"
    echo ""
    echo "SSH access restricted to: sysadmin only"
    echo ""
    echo "Check logs with:"
    echo "  sudo journalctl -u dovecot -f"
    echo "  sudo tail -f /var/log/maillog"
    echo -e "==============================================\n${NC}"
}

# =============================================================================
# MAIN
# =============================================================================
main() {
    # Must run as root
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root (sudo)."
        exit 1
    fi

    gather_input
    set_hostname
    configure_hosts
    configure_dns
    install_packages
    configure_kerberos
    join_domain
    configure_sssd
    configure_authselect
    configure_pam
    configure_postfix
    configure_dovecot
    restrict_ssh
    start_services
    verify_setup
}

main
