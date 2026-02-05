# auditd

Competition-safe auditd deployment + lightweight alerting hooks.

This role is meant to be **fast**, **idempotent**, and **portable** across your Linux targets.
It installs auditd, applies a curated ruleset, ensures the service is running, and (optionally)
deploys the Discord sender utility used by other roles (FIM, etc.).

> If your team decides to expand audit rules later, do it deliberately. Auditd can get noisy fast
> and can cause scoring pain if you crank it up without tuning.

---

## What this role does

- Installs auditd packages on supported distros
- Loads audit rules from `/etc/audit/rules.d/` and applies them
- Ensures the audit daemon is enabled + running
- Provides a Discord sender script path that other roles can use (best effort)

---

## What this role does *not* do

- It is **not** a full “IDS platform”
- It does **not** guarantee “100+ rules”, “hourly summaries”, or auto-archival unless your tasks actually deploy those
- It does **not** ship logs to Splunk (UF handles forwarding; this role focuses on audit generation)

---

## Where it runs

This role is included in your `playbooks/02-critical-path.yml` under the `auditd` tag.

Typical execution:

```bash
ansible-playbook -i inventory/production.ini playbooks/02-critical-path.yml --tags auditd
````

---

## Requirements

* Ansible 2.15+
* SSH access with sudo
* Enough space for audit logs under `/var/log` (audit log growth depends on rules)

Supported targets (based on your repo intent):

* Debian/Ubuntu family
* Fedora/RHEL family

---

## Key variables (expected interface)

These names should match whatever is in `roles/auditd/defaults/main.yml` (and your tasks).
If your defaults use different names, update this README to match reality.

```yml
auditd_enabled: true

# Enable/disable Discord sender deployment or usage (best effort)
auditd_enable_discord_sender: true

# If you store webhook in vault, point to it here (optional)
auditd_discord_webhook_url: "{{ vault_discord_webhook_url | default('') }}"

# Where the sender script lives (used by other roles too)
auditd_discord_sender_path: "/usr/local/bin/ccdc-audit-alerts/send-discord-alert.py"
```

---

## Validation / sanity checks

### Service health

```bash
ansible all -m command -a "systemctl is-active auditd" -b
ansible all -m command -a "systemctl is-enabled auditd" -b
```

### Rules loaded

```bash
ansible all -m command -a "auditctl -l | head" -b
ansible all -m command -a "auditctl -l | wc -l" -b
```

> Don’t hardcode an “expected” rule count unless you actually enforce that count in the role.
> The count depends on your rules files.

### Generate a quick test event

This is safer than touching `/etc` during a match:

```bash
ansible HOST -m command -a "logger 'CCDC audit test'" -b
ansible HOST -m command -a "ausearch -ts recent | head -25" -b
```

If your rules include a key-based watch (ex: `-k ccdc_*`), then you can validate with:

```bash
ansible HOST -m command -a "ausearch -k ccdc -ts recent | head -25" -b
```

---

## Troubleshooting

### auditd won’t start

```bash
ansible HOST -m command -a "journalctl -u auditd -n 80 --no-pager" -b
ansible HOST -m command -a "augenrules --check" -b
```

If `augenrules --check` reports a problem, your rules file syntax is the usual culprit.

### rules didn’t apply

```bash
ansible HOST -m command -a "ls -la /etc/audit/rules.d/" -b
ansible HOST -m command -a "augenrules --load" -b
ansible HOST -m command -a "auditctl -l | head -50" -b
```

---

## Notes

* Be cautious with “monitor whole directories” rules (`/usr/bin`, `/etc`, etc.). They can create a ton of events.
* Keep rule changes intentional and test them on one host first (`--limit ecom` etc.).
