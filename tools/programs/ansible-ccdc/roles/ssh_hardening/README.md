# ssh_hardening

Competition-safe SSH hardening role.

This role is designed for **CCDC-style constraints**:
- Keep SSH on port 22 (don’t break scoring or remote access assumptions)
- Reduce risk of lockout (keys first, then hardening)
- Make changes idempotent and reversible (backup + syntax check)

---

## What this role does

- Applies a hardened SSH daemon configuration (sshd)
- Keeps SSH access viable for the operator account (typically `sysadmin`)
- Performs safety checks before restarting SSH:
  - config backup (best effort)
  - `sshd -t` validation (syntax check)
  - controlled restart/reload

> Exactly which sshd options are enforced depends on the tasks/templates in this role.
> This README intentionally avoids claiming features you may not have implemented.

---

## What this role does *not* do

- Does **not** change the SSH port (stays 22)
- Does **not** deploy SSH keys (that’s handled by `playbooks/00-bootstrap-keys.yml`)
- Does **not** manage host firewall rules (handled by the firewall role)
- Does **not** promise fail2ban setup, crypto suite pinning, or root account modifications unless you explicitly add them

---

## Where it runs

This role is executed as part of the Critical Path playbook:

- `playbooks/02-critical-path.yml` (tag: `ssh`)

Run it by itself:

```bash
ansible-playbook -i inventory/production.ini playbooks/02-critical-path.yml --tags ssh
````

---

## Prerequisites

1. **SSH keys must already work** (don’t harden a host you can’t key-auth to)

   * Use: `playbooks/00-bootstrap-keys.yml`

2. Sudo access for the operator user (usually `sysadmin`)

---

## Variables

Document only the knobs that actually exist in your role defaults/vars.
If your role has no public variables, keep this section minimal.

Common patterns you *may* have (update to match your repo):

```yml
# Example toggles (only keep the ones your role actually uses)
ssh_hardening_disable_password_auth: true
ssh_hardening_permit_root_login: "no"
ssh_hardening_config_path: "/etc/ssh/sshd_config"
```

---

## Validation

### Before hardening

```bash
# confirm you can reach the host(s)
ansible -i inventory/production.ini linux_servers -m ping

# confirm key-based SSH works from your controller
ssh -i ~/.ssh/ccdc_rsa sysadmin@<host>
```

### After hardening

```bash
# confirm SSH still works
ansible -i inventory/production.ini linux_servers -m ping

# confirm sshd config is valid (use the correct path on the host)
ansible -i inventory/production.ini linux_servers -m command -a "sshd -t" -b
```

---

## Troubleshooting

### Locked out risk

If you disable password auth before key auth is verified, you can lock yourself out.

Correct order:

1. `playbooks/00-bootstrap-keys.yml`
2. Validate SSH using your key
3. Run critical path (includes this role)

### sshd won’t restart

```bash
ansible HOST -m command -a "sshd -t" -b
ansible HOST -m command -a "journalctl -u ssh -n 80 --no-pager" -b
ansible HOST -m command -a "journalctl -u sshd -n 80 --no-pager" -b
```
