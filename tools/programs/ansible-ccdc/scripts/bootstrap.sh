#!/usr/bin/env bash
set -Eeuo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

NONINTERACTIVE=0

for arg in "$@"; do
  case "$arg" in
    -n|--non-interactive) NONINTERACTIVE=1 ;;
  esac
done

ok()   { echo -e "${GREEN}✓${NC} $*"; }
warn() { echo -e "${YELLOW}!${NC} $*"; }
die()  { echo -e "${RED}✗${NC} $*" >&2; exit 1; }

on_err() {
  local ec=$?
  echo -e "${RED}✗${NC} Bootstrap failed (exit=${ec})" >&2
  echo -e "${RED}✗${NC} Line: ${BASH_LINENO[0]}  Cmd: ${BASH_COMMAND}" >&2
  exit "$ec"
}
trap on_err ERR

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
cd "$REPO_ROOT"

VENV_DIR="${REPO_ROOT}/.venv"
VAULT_FILE="${HOME}/.vault_pass"
KEY_PATH="${HOME}/.ssh/ccdc_rsa"

EXPECTED_INVENTORY="inventory/production.ini"
EXPECTED_REMOTE_USER="sysadmin"
EXPECTED_TIMEOUT="10"
EXPECTED_FORKS="10"
EXPECTED_FACT_CACHE="/tmp/ansible_facts"

echo -e "${YELLOW}=== MWCCDC Ansible Bootstrap ===${NC}"

if [[ -f /etc/arch-release ]]; then
  ENV="arch"
  ok "Environment: Arch Linux"
elif command -v apt-get >/dev/null 2>&1; then
  ENV="debian"
  ok "Environment: Debian/Ubuntu"
elif command -v dnf >/dev/null 2>&1; then
  ENV="fedora"
  ok "Environment: Fedora/RHEL"
else
  die "Unsupported distribution (need pacman/apt/dnf)"
fi

echo -e "\n${YELLOW}Installing system dependencies...${NC}"
case "$ENV" in
  arch)
    sudo pacman -Sy --noconfirm >/dev/null 2>&1 || true
    sudo pacman -S --noconfirm python python-pip python-virtualenv sshpass git >/dev/null 2>&1
    ;;
  debian)
    sudo apt-get update -qq
    sudo apt-get install -y -qq python3 python3-pip python3-venv sshpass git
    ;;
  fedora)
    sudo dnf install -y python3 python3-pip python3-virtualenv sshpass git
    ;;
esac
ok "System packages ready"

echo -e "\n${YELLOW}Preparing Python virtual environment...${NC}"
if [[ ! -d "$VENV_DIR" ]]; then
  python3 -m venv "$VENV_DIR"
  ok "Created venv: ${VENV_DIR}"
else
  ok "Venv exists: ${VENV_DIR}"
fi

# shellcheck disable=SC1091
source "${VENV_DIR}/bin/activate"
ok "Virtual environment active"

echo -e "\n${YELLOW}Installing Ansible...${NC}"
pip install --upgrade pip setuptools wheel >/dev/null
pip install "ansible-core==2.16.0" >/dev/null
ok "$(ansible --version | head -1)"

if [[ -f "${REPO_ROOT}/requirements.yml" ]]; then
  echo -e "\n${YELLOW}Installing Ansible collections (requirements.yml)...${NC}"
  ansible-galaxy collection install -r requirements.yml --force
  ok "Collections installed"
else
  warn "requirements.yml not found; skipping collection install"
fi

echo -e "\n${YELLOW}Validating vault configuration...${NC}"
if [[ ! -f "$VAULT_FILE" ]]; then
  warn "Vault password file not found: $VAULT_FILE"
  echo "Creating it now (permissions: 0600). Input will be hidden."
  echo ""

  if [[ $NONINTERACTIVE -eq 1 ]]; then
    die "Non-interactive mode but ~/.vault_pass is missing. Create it first."
  fi

  read -r -s -p "Enter vault password: " VP1; echo ""
  read -r -s -p "Confirm vault password: " VP2; echo ""
  echo ""

  [[ -n "${VP1}" ]] || die "Vault password cannot be empty"
  [[ "${VP1}" == "${VP2}" ]] || die "Vault passwords did not match"

  umask 077
  tmpfile="$(mktemp "${VAULT_FILE}.XXXXXX")"
  printf '%s\n' "$VP1" > "$tmpfile"
  chmod 600 "$tmpfile"
  mv -f "$tmpfile" "$VAULT_FILE"
  unset VP1 VP2

  ok "Vault password file created: $VAULT_FILE"
else
  chmod 600 "$VAULT_FILE" || true
  ok "Vault password file present: $VAULT_FILE"
fi

# ### CHANGED: make sanity check explicit (so a failure gives a clear error)
if [[ -f "${REPO_ROOT}/group_vars/all/vault.yml" ]]; then
  if ! ansible-vault view "${REPO_ROOT}/group_vars/all/vault.yml" --vault-password-file "$VAULT_FILE" >/dev/null; then
    die "Vault decrypt sanity check failed. ~/.vault_pass does not match this repo."
  fi
  ok "Vault decrypt sanity check passed"
else
  warn "group_vars/all/vault.yml not found; skipping decrypt sanity check"
fi

echo -e "\n${YELLOW}Validating ansible.cfg...${NC}"
CFG="${REPO_ROOT}/ansible.cfg"

if [[ ! -f "$CFG" ]]; then
  warn "ansible.cfg not found in repo root. Creating competition-safe ansible.cfg..."
  cat > "$CFG" << EOF
[defaults]
private_key_file = ${KEY_PATH}
inventory = ${EXPECTED_INVENTORY}
vault_password_file = ${VAULT_FILE}
host_key_checking = False
timeout = ${EXPECTED_TIMEOUT}
remote_user = ${EXPECTED_REMOTE_USER}
forks = ${EXPECTED_FORKS}
retry_files_enabled = False

gathering = smart
fact_caching = jsonfile
fact_caching_connection = ${EXPECTED_FACT_CACHE}
fact_caching_timeout = 3600

roles_path = roles:${HOME}/.ansible/roles:/usr/share/ansible/roles:/etc/ansible/roles

[ssh_connection]
pipelining = True
ssh_args = -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null

[privilege_escalation]
become = True
become_method = sudo
become_ask_pass = False
EOF
  ok "ansible.cfg created"
else
  ok "ansible.cfg present"
fi

# ### CHANGED: use if/else (avoids ERR trap firing on grep “no match”)
if grep -qE "^\s*inventory\s*=\s*${EXPECTED_INVENTORY}\s*$" "$CFG"; then
  ok "ansible.cfg inventory = ${EXPECTED_INVENTORY}"
else
  warn "ansible.cfg inventory is not '${EXPECTED_INVENTORY}'"
fi

if grep -qE "^\s*private_key_file\s*=" "$CFG"; then
  ok "ansible.cfg private_key_file is set"
else
  warn "ansible.cfg private_key_file is not set"
fi

if grep -qE "^\s*vault_password_file\s*=\s*${HOME}/\.vault_pass\s*$" "$CFG"; then
  ok "ansible.cfg vault_password_file = ~/.vault_pass"
else
  warn "ansible.cfg vault_password_file is not '~/.vault_pass'"
fi

echo -e "\n${YELLOW}Ensuring SSH keypair exists...${NC}"
mkdir -p "${HOME}/.ssh"
chmod 700 "${HOME}/.ssh"

if [[ ! -f "$KEY_PATH" ]]; then
  ssh-keygen -t rsa -b 4096 -f "$KEY_PATH" -N "" -C "ccdc@$(hostname)" >/dev/null
  chmod 600 "$KEY_PATH"
  chmod 644 "${KEY_PATH}.pub"
  ok "SSH key generated: $KEY_PATH"
else
  ok "SSH key already present: $KEY_PATH"
fi

if [[ $NONINTERACTIVE -eq 1 ]]; then
  warn "Non-interactive mode: skipping SSH key bootstrap prompt"
else
  echo ""
  read -r -p "Run SSH key bootstrap now? [y/N]: " REPLY
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Running playbooks/00-bootstrap-keys.yml...${NC}"
    ansible-playbook playbooks/00-bootstrap-keys.yml -k
    ok "SSH key bootstrap completed"
  else
    warn "Skipping SSH key bootstrap"
  fi
fi

echo -e "\n${GREEN}=== Bootstrap Complete ===${NC}"
echo "Repo:        ${REPO_ROOT}"
echo "Environment: ${ENV}"
echo "Ansible:     $(ansible --version | head -1)"
echo "Venv:        ${VENV_DIR}"
echo "Vault file:  ${VAULT_FILE} (0600)"
echo "SSH key:     ${KEY_PATH}"
echo ""
echo "Next steps:"
echo "  ansible-playbook -i ${EXPECTED_INVENTORY} playbooks/02-critical-path.yml"
echo ""
