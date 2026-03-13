#!/bin/bash
# =============================================================================
# CCDC Mail Server Backup & Restore Script
# Backs up and restores all critical mail server configuration files
# =============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Backup location
BACKUP_ROOT="/root/mail_backups"

# List of all critical config files
CONFIG_FILES=(
    # Postfix
    "/etc/postfix/main.cf"
    "/etc/postfix/master.cf"
    # Dovecot
    "/etc/dovecot/dovecot.conf"
    "/etc/dovecot/conf.d/10-auth.conf"
    "/etc/dovecot/conf.d/10-mail.conf"
    "/etc/dovecot/conf.d/10-master.conf"
    "/etc/dovecot/conf.d/10-ssl.conf"
    "/etc/dovecot/conf.d/20-pop3.conf"
    "/etc/dovecot/conf.d/auth-pam.conf.ext"
    # SSSD
    "/etc/sssd/sssd.conf"
    # Kerberos
    "/etc/krb5.conf"
    "/etc/krb5.keytab"
    # PAM
    "/etc/pam.d/dovecot"
    "/etc/pam.d/system-auth"
    "/etc/pam.d/password-auth"
    # System
    "/etc/hosts"
    "/etc/resolv.conf"
    "/etc/hostname"
    "/etc/ssh/sshd_config"
)

print_banner() {
    echo -e "${BLUE}"
    echo "=============================================="
    echo "   CCDC Mail Server Backup & Restore Script"
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
# BACKUP FUNCTION
# =============================================================================
backup() {
    print_step "Starting backup..."

    # Create timestamped backup directory
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    BACKUP_DIR="${BACKUP_ROOT}/${TIMESTAMP}"
    mkdir -p "$BACKUP_DIR"

    BACKED_UP=0
    SKIPPED=0

    for FILE in "${CONFIG_FILES[@]}"; do
        if [ -f "$FILE" ]; then
            # Recreate directory structure inside backup folder
            DIR=$(dirname "$FILE")
            mkdir -p "${BACKUP_DIR}${DIR}"
            cp "$FILE" "${BACKUP_DIR}${FILE}"
            print_info "Backed up: $FILE"
            ((BACKED_UP++))
        else
            print_info "Skipped (not found): $FILE"
            ((SKIPPED++))
        fi
    done

    # Save a manifest of what was backed up
    echo "Backup created: $(date)" > "${BACKUP_DIR}/MANIFEST.txt"
    echo "Backed up: $BACKED_UP files" >> "${BACKUP_DIR}/MANIFEST.txt"
    echo "Skipped: $SKIPPED files" >> "${BACKUP_DIR}/MANIFEST.txt"
    echo "" >> "${BACKUP_DIR}/MANIFEST.txt"
    echo "Files backed up:" >> "${BACKUP_DIR}/MANIFEST.txt"
    for FILE in "${CONFIG_FILES[@]}"; do
        [ -f "$FILE" ] && echo "  $FILE" >> "${BACKUP_DIR}/MANIFEST.txt"
    done

    echo ""
    print_success "Backup complete!"
    print_info "Location  : $BACKUP_DIR"
    print_info "Files     : $BACKED_UP backed up, $SKIPPED skipped"
}

# =============================================================================
# LIST BACKUPS FUNCTION
# =============================================================================
list_backups() {
    print_step "Available backups:"

    if [ ! -d "$BACKUP_ROOT" ] || [ -z "$(ls -A $BACKUP_ROOT 2>/dev/null)" ]; then
        print_error "No backups found in $BACKUP_ROOT"
        exit 1
    fi

    echo ""
    INDEX=1
    for DIR in "$BACKUP_ROOT"/*/; do
        DIRNAME=$(basename "$DIR")
        # Format timestamp for display
        DISPLAY_DATE=$(echo "$DIRNAME" | sed 's/\([0-9]\{4\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)_\([0-9]\{2\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)/\1-\2-\3 \4:\5:\6/')
        FILE_COUNT=$(find "$DIR" -type f ! -name "MANIFEST.txt" | wc -l)
        echo "  [$INDEX] $DISPLAY_DATE  ($FILE_COUNT files)"
        ((INDEX++))
    done
    echo ""
}

# =============================================================================
# RESTORE FUNCTION
# =============================================================================
restore() {
    print_step "Starting restore..."

    if [ ! -d "$BACKUP_ROOT" ] || [ -z "$(ls -A $BACKUP_ROOT 2>/dev/null)" ]; then
        print_error "No backups found in $BACKUP_ROOT"
        exit 1
    fi

    # List available backups
    list_backups

    # Get list of backup dirs as array
    BACKUP_DIRS=("$BACKUP_ROOT"/*/)

    read -p "Enter the number of the backup to restore (or 'q' to quit): " CHOICE

    if [[ "$CHOICE" == "q" || "$CHOICE" == "Q" ]]; then
        print_info "Restore cancelled."
        exit 0
    fi

    # Validate input
    if ! [[ "$CHOICE" =~ ^[0-9]+$ ]] || [ "$CHOICE" -lt 1 ] || [ "$CHOICE" -gt "${#BACKUP_DIRS[@]}" ]; then
        print_error "Invalid selection."
        exit 1
    fi

    SELECTED_BACKUP="${BACKUP_DIRS[$((CHOICE-1))]}"
    SELECTED_NAME=$(basename "$SELECTED_BACKUP")

    echo ""
    print_info "Selected backup: $SELECTED_NAME"
    read -p "Are you sure you want to restore this backup? This will overwrite current configs. (y/n): " CONFIRM

    if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
        print_info "Restore cancelled."
        exit 0
    fi

    # Stop services before restore
    print_info "Stopping services..."
    systemctl stop postfix dovecot sssd 2>/dev/null || true

    # Restore each file
    RESTORED=0
    SKIPPED=0

    for FILE in "${CONFIG_FILES[@]}"; do
        BACKUP_FILE="${SELECTED_BACKUP}${FILE}"
        if [ -f "$BACKUP_FILE" ]; then
            DIR=$(dirname "$FILE")
            mkdir -p "$DIR"
            cp "$BACKUP_FILE" "$FILE"
            # Restore original permissions for sensitive files
            case "$FILE" in
                /etc/sssd/sssd.conf)
                    chmod 600 "$FILE"
                    ;;
                /etc/krb5.keytab)
                    chmod 600 "$FILE"
                    ;;
                /etc/ssh/sshd_config)
                    chmod 600 "$FILE"
                    ;;
            esac
            print_info "Restored: $FILE"
            ((RESTORED++))
        else
            print_info "Skipped (not in backup): $FILE"
            ((SKIPPED++))
        fi
    done

    # Restart services after restore
    print_info "Restarting services..."
    sss_cache -E 2>/dev/null || true
    systemctl restart sssd
    systemctl restart postfix
    systemctl restart dovecot
    systemctl restart sshd

    echo ""
    print_success "Restore complete!"
    print_info "Restored : $RESTORED files"
    print_info "Skipped  : $SKIPPED files"

    # Quick service check
    echo ""
    print_step "Service status after restore:"
    systemctl is-active sssd && print_success "SSSD is running" || print_error "SSSD is NOT running"
    systemctl is-active postfix && print_success "Postfix is running" || print_error "Postfix is NOT running"
    systemctl is-active dovecot && print_success "Dovecot is running" || print_error "Dovecot is NOT running"
}

# =============================================================================
# VERIFY FUNCTION
# Compare current configs against a backup to detect tampering
# =============================================================================
verify() {
    print_step "Verifying current configs against a backup..."

    if [ ! -d "$BACKUP_ROOT" ] || [ -z "$(ls -A $BACKUP_ROOT 2>/dev/null)" ]; then
        print_error "No backups found in $BACKUP_ROOT"
        exit 1
    fi

    list_backups

    BACKUP_DIRS=("$BACKUP_ROOT"/*/)

    read -p "Enter the number of the backup to compare against: " CHOICE

    if ! [[ "$CHOICE" =~ ^[0-9]+$ ]] || [ "$CHOICE" -lt 1 ] || [ "$CHOICE" -gt "${#BACKUP_DIRS[@]}" ]; then
        print_error "Invalid selection."
        exit 1
    fi

    SELECTED_BACKUP="${BACKUP_DIRS[$((CHOICE-1))]}"
    SELECTED_NAME=$(basename "$SELECTED_BACKUP")

    echo ""
    print_info "Comparing current configs against backup: $SELECTED_NAME"
    echo ""

    MODIFIED=0
    MISSING=0
    OK=0

    for FILE in "${CONFIG_FILES[@]}"; do
        BACKUP_FILE="${SELECTED_BACKUP}${FILE}"
        if [ ! -f "$BACKUP_FILE" ]; then
            continue
        fi
        if [ ! -f "$FILE" ]; then
            echo -e "  ${RED}[MISSING]${NC}  $FILE"
            ((MISSING++))
        elif ! diff -q "$FILE" "$BACKUP_FILE" > /dev/null 2>&1; then
            echo -e "  ${RED}[MODIFIED]${NC} $FILE"
            ((MODIFIED++))
        else
            echo -e "  ${GREEN}[OK]${NC}       $FILE"
            ((OK++))
        fi
    done

    echo ""
    print_info "Results: $OK unchanged, $MODIFIED modified, $MISSING missing"

    if [ "$MODIFIED" -gt 0 ] || [ "$MISSING" -gt 0 ]; then
        echo ""
        print_error "WARNING: $((MODIFIED + MISSING)) file(s) have been changed or are missing!"
        print_info "Run '$0 restore' to restore from backup."
    else
        print_success "All configs match the backup — no tampering detected."
    fi
}

# =============================================================================
# MENU
# =============================================================================
show_menu() {
    print_banner
    echo "What would you like to do?"
    echo ""
    echo "  [1] Backup current configs"
    echo "  [2] Restore from a backup"
    echo "  [3] List available backups"
    echo "  [4] Verify configs against a backup (detect tampering)"
    echo "  [5] Exit"
    echo ""
    read -p "Enter your choice: " MENU_CHOICE

    case "$MENU_CHOICE" in
        1) backup ;;
        2) restore ;;
        3) list_backups ;;
        4) verify ;;
        5) exit 0 ;;
        *) print_error "Invalid choice."; show_menu ;;
    esac
}

# =============================================================================
# MAIN
# =============================================================================
if [[ $EUID -ne 0 ]]; then
    print_error "This script must be run as root (sudo)."
    exit 1
fi

# Allow passing action as argument for quick use
# e.g. sudo bash mail_backup.sh backup
case "$1" in
    backup)  print_banner; backup ;;
    restore) print_banner; restore ;;
    list)    print_banner; list_backups ;;
    verify)  print_banner; verify ;;
    *)       show_menu ;;
esac
