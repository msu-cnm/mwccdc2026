#!/bin/bash
# =============================================================================
# CCDC Mail Server Audit Script
# Scans for backdoors, suspicious files, and security threats
# =============================================================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Report file
REPORT_DIR="/root/audit_reports"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
REPORT_FILE="${REPORT_DIR}/audit_${TIMESTAMP}.txt"

WARNINGS=0
CRITICAL=0

mkdir -p "$REPORT_DIR"

# =============================================================================
# OUTPUT HELPERS
# =============================================================================
print_banner() {
    echo -e "${BLUE}"
    echo "=============================================="
    echo "   CCDC Mail Server Audit Script"
    echo "   $(date)"
    echo "=============================================="
    echo -e "${NC}"
}

print_section() {
    echo -e "\n${CYAN}══════════════════════════════════════════${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}══════════════════════════════════════════${NC}"
    log "\n══════════════════════════════════════════"
    log "  $1"
    log "══════════════════════════════════════════"
}

print_ok() {
    echo -e "  ${GREEN}[OK]${NC}       $1"
    log "  [OK]       $1"
}

print_warn() {
    echo -e "  ${YELLOW}[WARNING]${NC}  $1"
    log "  [WARNING]  $1"
    ((WARNINGS++)) || true
}

print_critical() {
    echo -e "  ${RED}[CRITICAL]${NC} $1"
    log "  [CRITICAL] $1"
    ((CRITICAL++)) || true
}

print_info() {
    echo -e "  ${YELLOW}[INFO]${NC}     $1"
    log "  [INFO]     $1"
}

log() {
    echo "$1" >> "$REPORT_FILE"
}

# =============================================================================
# 1. SUSPICIOUS USERS & GROUPS
# =============================================================================
check_users() {
    print_section "Checking Users & Groups"

    # Users with login shells
    print_info "Users with login shells:"
    SHELL_USERS=$(cat /etc/passwd | grep -v nologin | grep -v false | grep -v halt | grep -v shutdown | grep -v sync)
    echo "$SHELL_USERS" | while read LINE; do
        USER=$(echo "$LINE" | cut -d: -f1)
        print_info "  Shell user: $USER"
    done
    log "$SHELL_USERS"

    # Users with UID 0 besides root
    ZERO_UIDS=$(awk -F: '($3 == 0 && $1 != "root")' /etc/passwd)
    if [ -n "$ZERO_UIDS" ]; then
        print_critical "Non-root user with UID 0 found: $ZERO_UIDS"
    else
        print_ok "No non-root UID 0 users found"
    fi

    # Check sudoers
    print_info "Sudoers entries:"
    SUDOERS=$(cat /etc/sudoers | grep -v "^#" | grep -v "^$")
    log "$SUDOERS"
    echo "$SUDOERS" | while read LINE; do
        print_info "  $LINE"
    done

    # Check sudoers.d
    if ls /etc/sudoers.d/ 2>/dev/null | grep -qv "README"; then
        SUDO_FILES=$(ls /etc/sudoers.d/ | grep -v README)
        print_warn "Files found in /etc/sudoers.d/: $SUDO_FILES"
        for F in $SUDO_FILES; do
            print_info "Contents of /etc/sudoers.d/$F:"
            cat "/etc/sudoers.d/$F" | grep -v "^#" | grep -v "^$" | while read LINE; do
                print_info "  $LINE"
            done
        done
    else
        print_ok "No unexpected files in /etc/sudoers.d/"
    fi

    # Recently created users
    print_info "Recently modified /etc/passwd:"
    PASSWD_MOD=$(find /etc -name "passwd" -mtime -7 2>/dev/null)
    if [ -n "$PASSWD_MOD" ]; then
        print_warn "/etc/passwd was modified in the last 7 days"
    else
        print_ok "/etc/passwd not recently modified"
    fi
}

# =============================================================================
# 2. RUNNING PROCESSES
# =============================================================================
check_processes() {
    print_section "Checking Running Processes"

    # Processes running as root that seem unusual
    print_info "All processes running as root:"
    ROOT_PROCS=$(ps aux | grep root | grep -v "\[" | grep -v grep | awk '{print $11}' | sort -u)
    log "$ROOT_PROCS"
    echo "$ROOT_PROCS" | while read PROC; do
        print_info "  $PROC"
    done

    # Look for common backdoor process names
    SUSPICIOUS_NAMES=("nc" "ncat" "netcat" "socat" "bash -i" "python -c" "perl -e" "ruby -e" "php -r" "meterpreter" "reverse" "backdoor")
    for NAME in "${SUSPICIOUS_NAMES[@]}"; do
        FOUND=$(ps aux | grep -i "$NAME" | grep -v grep)
        if [ -n "$FOUND" ]; then
            print_critical "Suspicious process found: $NAME"
            log "$FOUND"
        fi
    done
    print_ok "Common backdoor process names checked"
}

# =============================================================================
# 3. NETWORK CONNECTIONS
# =============================================================================
check_network() {
    print_section "Checking Network Connections"

    # Listening ports
    print_info "All listening ports:"
    LISTENING=$(ss -tulnp)
    log "$LISTENING"
    echo "$LISTENING" | while read LINE; do
        print_info "  $LINE"
    done

    # Established outbound connections
    print_info "Established outbound connections:"
    ESTABLISHED=$(ss -tunp | grep ESTABLISHED)
    if [ -n "$ESTABLISHED" ]; then
        print_warn "Active outbound connections found:"
        log "$ESTABLISHED"
        echo "$ESTABLISHED" | while read LINE; do
            print_warn "  $LINE"
        done
    else
        print_ok "No unexpected outbound connections"
    fi

    # Check for unexpected ports (anything not 22, 25, 110, 995, 993, 443)
    EXPECTED_PORTS="22|25|110|143|443|587|993|995|53|88|389"
    UNEXPECTED=$(ss -tulnp | grep LISTEN | grep -v -E ":($EXPECTED_PORTS)\s")
    if [ -n "$UNEXPECTED" ]; then
        print_critical "Unexpected listening ports found:"
        echo "$UNEXPECTED" | while read LINE; do
            print_critical "  $LINE"
        done
        log "$UNEXPECTED"
    else
        print_ok "No unexpected listening ports found"
    fi
}

# =============================================================================
# 4. CRON JOBS
# =============================================================================
check_cron() {
    print_section "Checking Cron Jobs"

    # System crontab
    print_info "System crontab (/etc/crontab):"
    CRONTAB=$(cat /etc/crontab | grep -v "^#" | grep -v "^$")
    if [ -n "$CRONTAB" ]; then
        print_warn "Entries found in /etc/crontab:"
        log "$CRONTAB"
        echo "$CRONTAB" | while read LINE; do
            print_warn "  $LINE"
        done
    else
        print_ok "/etc/crontab is empty"
    fi

    # Cron directories
    for CRONDIR in /etc/cron.d /etc/cron.hourly /etc/cron.daily /etc/cron.weekly /etc/cron.monthly; do
        FILES=$(ls "$CRONDIR" 2>/dev/null | grep -v "0hourly" | grep -v "dailyjobs" | grep -v "sysstat" | grep -v "raid-check" | grep -v "logrotate" | grep -v "man-db")
        if [ -n "$FILES" ]; then
            print_warn "Unexpected files in $CRONDIR: $FILES"
            for F in $FILES; do
                print_info "Contents of $CRONDIR/$F:"
                cat "$CRONDIR/$F" 2>/dev/null | grep -v "^#" | grep -v "^$" | while read LINE; do
                    print_warn "  $LINE"
                done
            done
        else
            print_ok "$CRONDIR looks clean"
        fi
    done

    # User crontabs
    print_info "Checking user crontabs:"
    for USER in $(cut -f1 -d: /etc/passwd); do
        USERCRON=$(crontab -u "$USER" -l 2>/dev/null | grep -v "^#" | grep -v "^$")
        if [ -n "$USERCRON" ]; then
            print_critical "Crontab found for user $USER:"
            log "$USERCRON"
            echo "$USERCRON" | while read LINE; do
                print_critical "  $LINE"
            done
        fi
    done

    # Systemd timers
    print_info "Systemd timers:"
    TIMERS=$(systemctl list-timers --all | grep -v "NEXT\|listed\|^$")
    log "$TIMERS"
    echo "$TIMERS" | while read LINE; do
        print_info "  $LINE"
    done
}

# =============================================================================
# 5. STARTUP SERVICES
# =============================================================================
check_services() {
    print_section "Checking Startup Services"

    # Expected services on a mail server
    EXPECTED_SERVICES=("postfix" "dovecot" "sssd" "sshd" "firewalld" "auditd" "fail2ban" "chronyd" "NetworkManager")

    # All enabled services
    print_info "All enabled services:"
    ENABLED=$(systemctl list-unit-files --state=enabled | grep ".service" | awk '{print $1}')
    log "$ENABLED"

    echo "$ENABLED" | while read SVC; do
        SVCNAME=$(echo "$SVC" | sed 's/.service//')
        IS_EXPECTED=false
        for EXP in "${EXPECTED_SERVICES[@]}"; do
            if [[ "$SVCNAME" == "$EXP" ]]; then
                IS_EXPECTED=true
                break
            fi
        done
        if [ "$IS_EXPECTED" = false ]; then
            print_warn "Unexpected enabled service: $SVC"
        fi
    done

    # Check for recently modified service files
    print_info "Recently modified systemd service files:"
    RECENT_SVCS=$(find /etc/systemd /usr/lib/systemd -name "*.service" -newer /etc/passwd 2>/dev/null)
    if [ -n "$RECENT_SVCS" ]; then
        print_critical "Recently modified service files found:"
        echo "$RECENT_SVCS" | while read F; do
            print_critical "  $F"
        done
        log "$RECENT_SVCS"
    else
        print_ok "No recently modified service files"
    fi
}

# =============================================================================
# 6. SSH BACKDOORS
# =============================================================================
check_ssh() {
    print_section "Checking SSH Backdoors"

    # Check authorized_keys for all users
    for DIR in /root /home/*; do
        USER=$(basename "$DIR")
        KEYFILE="$DIR/.ssh/authorized_keys"
        if [ -f "$KEYFILE" ]; then
            KEY_COUNT=$(wc -l < "$KEYFILE")
            print_critical "authorized_keys found for $USER ($KEY_COUNT keys):"
            while read KEY; do
                print_critical "  $KEY"
            done < "$KEYFILE"
            log "$(cat $KEYFILE)"
        else
            print_ok "No authorized_keys for $USER"
        fi
    done

    # Check sshd_config for suspicious settings
    print_info "Key SSH config settings:"
    PERMIT_ROOT=$(grep "^PermitRootLogin" /etc/ssh/sshd_config 2>/dev/null)
    ALLOW_USERS=$(grep "^AllowUsers" /etc/ssh/sshd_config 2>/dev/null)
    PASSWD_AUTH=$(grep "^PasswordAuthentication" /etc/ssh/sshd_config 2>/dev/null)

    [ -n "$PERMIT_ROOT" ] && print_info "  $PERMIT_ROOT" || print_warn "PermitRootLogin not explicitly set"
    [ -n "$ALLOW_USERS" ] && print_info "  $ALLOW_USERS" || print_warn "AllowUsers not set — all users can SSH"
    [ -n "$PASSWD_AUTH" ] && print_info "  $PASSWD_AUTH" || print_info "  PasswordAuthentication not explicitly set"
}

# =============================================================================
# 7. SUID/SGID FILES
# =============================================================================
check_suid() {
    print_section "Checking SUID/SGID Files"

    # Known legitimate SUID files
    KNOWN_SUID=("/usr/bin/sudo" "/usr/bin/su" "/usr/bin/passwd" "/usr/bin/chsh" 
                "/usr/bin/chfn" "/usr/bin/newgrp" "/usr/bin/gpasswd" "/usr/bin/mount"
                "/usr/bin/umount" "/usr/bin/pkexec" "/usr/sbin/unix_chkpwd"
                "/usr/libexec/openssh/ssh-keysign")

    print_info "Scanning for SUID files (this may take a moment)..."
    SUID_FILES=$(find / -perm -4000 -type f 2>/dev/null | grep -v /proc | grep -v /sys)

    echo "$SUID_FILES" | while read FILE; do
        IS_KNOWN=false
        for KNOWN in "${KNOWN_SUID[@]}"; do
            if [[ "$FILE" == "$KNOWN" ]]; then
                IS_KNOWN=true
                break
            fi
        done
        if [ "$IS_KNOWN" = false ]; then
            print_critical "Unexpected SUID file: $FILE"
        else
            print_ok "Known SUID: $FILE"
        fi
    done
    log "$SUID_FILES"
}

# =============================================================================
# 8. RECENTLY MODIFIED FILES
# =============================================================================
check_modified_files() {
    print_section "Checking Recently Modified Files"

    # Recently modified binaries
    print_info "Checking for recently modified system binaries..."
    MODIFIED_BINS=$(find /bin /sbin /usr/bin /usr/sbin -mtime -3 -type f 2>/dev/null)
    if [ -n "$MODIFIED_BINS" ]; then
        print_critical "Recently modified binaries found:"
        echo "$MODIFIED_BINS" | while read F; do
            print_critical "  $F"
        done
        log "$MODIFIED_BINS"
    else
        print_ok "No recently modified system binaries"
    fi

    # Recently modified config files
    print_info "Recently modified config files (last 24hrs):"
    MODIFIED_CONFIGS=$(find /etc -mtime -1 -type f 2>/dev/null | grep -v "\.swp" | grep -v adjtime)
    if [ -n "$MODIFIED_CONFIGS" ]; then
        print_warn "Recently modified config files:"
        echo "$MODIFIED_CONFIGS" | while read F; do
            print_warn "  $F"
        done
        log "$MODIFIED_CONFIGS"
    else
        print_ok "No config files modified in last 24 hours"
    fi

    # Suspicious files in temp directories
    print_info "Checking temp directories..."
    TMP_FILES=$(find /tmp /var/tmp /dev/shm -type f 2>/dev/null)
    if [ -n "$TMP_FILES" ]; then
        print_critical "Files found in temp directories:"
        echo "$TMP_FILES" | while read F; do
            print_critical "  $F"
        done
        log "$TMP_FILES"
    else
        print_ok "Temp directories are clean"
    fi

    # Files with no owner
    print_info "Checking for unowned files..."
    UNOWNED=$(find / -nouser -type f 2>/dev/null | grep -v /proc | grep -v /sys)
    if [ -n "$UNOWNED" ]; then
        print_warn "Unowned files found:"
        echo "$UNOWNED" | while read F; do
            print_warn "  $F"
        done
        log "$UNOWNED"
    else
        print_ok "No unowned files found"
    fi
}

# =============================================================================
# 9. BASH HISTORY & PROFILES
# =============================================================================
check_history() {
    print_section "Checking Bash History & Profiles"

    # Check bash history for suspicious commands
    SUSPICIOUS_CMDS=("nc " "ncat " "netcat " "socat " "wget " "curl " "base64" "chmod 777" "chmod +s" "/dev/tcp" "/dev/udp" "python -c" "perl -e" "bash -i")

    for HISTFILE in /root/.bash_history /home/*/.bash_history; do
        if [ -f "$HISTFILE" ]; then
            USER=$(echo "$HISTFILE" | cut -d/ -f3)
            [ "$USER" == "root" ] && USER="root"
            print_info "Checking history for $USER:"
            for CMD in "${SUSPICIOUS_CMDS[@]}"; do
                FOUND=$(grep -i "$CMD" "$HISTFILE" 2>/dev/null)
                if [ -n "$FOUND" ]; then
                    print_critical "Suspicious command in ${USER}'s history: $CMD"
                    log "$FOUND"
                fi
            done
        fi
    done

    # Check shell profiles for malicious entries
    PROFILE_FILES=("/etc/profile" "/etc/bashrc" "/root/.bashrc" "/root/.bash_profile" "/root/.profile")
    for F in "${PROFILE_FILES[@]}"; do
        if [ -f "$F" ]; then
            SUSPICIOUS=$(grep -iE "(nc |ncat|netcat|socat|base64|/dev/tcp|wget|curl)" "$F" 2>/dev/null)
            if [ -n "$SUSPICIOUS" ]; then
                print_critical "Suspicious entry in $F:"
                echo "$SUSPICIOUS" | while read LINE; do
                    print_critical "  $LINE"
                done
                log "$SUSPICIOUS"
            else
                print_ok "$F looks clean"
            fi
        fi
    done

    # Check /etc/profile.d/
    print_info "Files in /etc/profile.d/:"
    ls /etc/profile.d/ 2>/dev/null | while read F; do
        print_info "  $F"
        SUSPICIOUS=$(grep -iE "(nc |ncat|netcat|socat|base64|/dev/tcp|wget|curl)" "/etc/profile.d/$F" 2>/dev/null)
        if [ -n "$SUSPICIOUS" ]; then
            print_critical "Suspicious entry in /etc/profile.d/$F:"
            log "$SUSPICIOUS"
        fi
    done
}

# =============================================================================
# 10. PAM BACKDOORS
# =============================================================================
check_pam() {
    print_section "Checking PAM Configuration"

    PAM_FILES=("/etc/pam.d/sshd" "/etc/pam.d/system-auth" "/etc/pam.d/sudo" "/etc/pam.d/dovecot" "/etc/pam.d/password-auth")

    for F in "${PAM_FILES[@]}"; do
        if [ -f "$F" ]; then
            # Look for pam_permit used suspiciously in auth
            PERMIT=$(grep "pam_permit" "$F" | grep "auth")
            if [ -n "$PERMIT" ]; then
                print_critical "pam_permit.so in auth section of $F — accepts ANY password!"
                log "$PERMIT"
            else
                print_ok "$F - no pam_permit in auth section"
            fi

            # Look for debug or other suspicious options
            SUSPICIOUS=$(grep -iE "(pam_exec|pam_script)" "$F" 2>/dev/null)
            if [ -n "$SUSPICIOUS" ]; then
                print_critical "Suspicious PAM module in $F: $SUSPICIOUS"
                log "$SUSPICIOUS"
            fi
        fi
    done
}

# =============================================================================
# 11. MAIL CONFIG CHECKS
# =============================================================================
check_mail_config() {
    print_section "Checking Mail Configuration"

    # Check for open relay
    print_info "Checking Postfix relay settings:"
    MYNETWORKS=$(postconf mynetworks 2>/dev/null)
    RELAY=$(postconf relay_domains 2>/dev/null)
    print_info "  $MYNETWORKS"
    print_info "  $RELAY"
    log "$MYNETWORKS"
    log "$RELAY"

    # Warn if mynetworks is too broad
    if echo "$MYNETWORKS" | grep -qE "0\.0\.0\.0|any"; then
        print_critical "Postfix mynetworks is too broad — possible open relay!"
    else
        print_ok "Postfix mynetworks looks reasonable"
    fi

    # Check /etc/aliases for forwarding
    print_info "Checking /etc/aliases for suspicious forwarding:"
    ALIASES=$(cat /etc/aliases | grep -v "^#" | grep -v "^$")
    if [ -n "$ALIASES" ]; then
        print_warn "Aliases found — review for suspicious forwarding:"
        echo "$ALIASES" | while read LINE; do
            print_warn "  $LINE"
        done
        log "$ALIASES"
    else
        print_ok "/etc/aliases is clean"
    fi

    # Check Dovecot for unexpected includes
    print_info "Checking Dovecot for unexpected config includes:"
    INCLUDES=$(grep -r "^!include" /etc/dovecot/ 2>/dev/null | grep -v "auth-pam\|10-auth")
    if [ -n "$INCLUDES" ]; then
        print_warn "Unexpected Dovecot includes:"
        echo "$INCLUDES" | while read LINE; do
            print_warn "  $LINE"
        done
        log "$INCLUDES"
    else
        print_ok "No unexpected Dovecot includes"
    fi
}

# =============================================================================
# 12. HOSTS FILE CHECK
# =============================================================================
check_hosts() {
    print_section "Checking /etc/hosts for Hijacking"

    print_info "Current /etc/hosts contents:"
    cat /etc/hosts | while read LINE; do
        print_info "  $LINE"
    done
    log "$(cat /etc/hosts)"

    # Check for suspicious redirects of common services
    SUSPICIOUS_HOSTS=$(grep -iE "(google|microsoft|fedora|redhat|centos|github|yum|dnf|update)" /etc/hosts 2>/dev/null)
    if [ -n "$SUSPICIOUS_HOSTS" ]; then
        print_critical "Suspicious redirect in /etc/hosts:"
        echo "$SUSPICIOUS_HOSTS" | while read LINE; do
            print_critical "  $LINE"
        done
        log "$SUSPICIOUS_HOSTS"
    else
        print_ok "No suspicious redirects in /etc/hosts"
    fi
}

# =============================================================================
# SUMMARY
# =============================================================================
print_summary() {
    echo ""
    echo -e "${BLUE}══════════════════════════════════════════${NC}"
    echo -e "${BLUE}  AUDIT SUMMARY${NC}"
    echo -e "${BLUE}══════════════════════════════════════════${NC}"

    if [ "$CRITICAL" -gt 0 ]; then
        echo -e "  ${RED}CRITICAL issues : $CRITICAL${NC}"
    else
        echo -e "  ${GREEN}CRITICAL issues : 0${NC}"
    fi

    if [ "$WARNINGS" -gt 0 ]; then
        echo -e "  ${YELLOW}WARNINGS        : $WARNINGS${NC}"
    else
        echo -e "  ${GREEN}WARNINGS        : 0${NC}"
    fi

    echo ""
    echo -e "  Full report saved to: ${CYAN}$REPORT_FILE${NC}"
    echo -e "${BLUE}══════════════════════════════════════════${NC}\n"

    log "\n══════════════════════════════════════════"
    log "  AUDIT SUMMARY"
    log "  CRITICAL issues : $CRITICAL"
    log "  WARNINGS        : $WARNINGS"
    log "══════════════════════════════════════════"
}

# =============================================================================
# MAIN
# =============================================================================
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}[ERROR]${NC} This script must be run as root (sudo)."
    exit 1
fi

print_banner
log "CCDC Mail Server Audit Report"
log "Generated: $(date)"
log "Hostname: $(hostname)"
log "=============================================="

check_users
check_processes
check_network
check_cron
check_services
check_ssh
check_suid
check_modified_files
check_history
check_pam
check_mail_config
check_hosts
print_summary
