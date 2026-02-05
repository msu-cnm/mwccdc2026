# fim_aide

AIDE-based file integrity monitoring (baseline hashes + periodic checks).

## What the role does

- Installs AIDE
- Injects a portable rule + host-aware scope into the system AIDE config
- Optionally initializes the baseline database (AIDE init)
- Deploys a cron-driven check script (with flock) that sends Discord alerts on differences/errors

## Host-aware scope

Define **both** of these per host (recommended) in `host_vars/<host>/fim.yml`:

```yml
fim_aide_paths:
  - /etc
  - /var/www

fim_aide_excludes:
  - /var/log
  - /run
  - /tmp
  - /var/spool
  - /var/lib/aide
```

This keeps noise down and avoids monitoring volatile areas.

## Baseline creation vs Critical Path

Creating the initial AIDE database can take several minutes on some hosts (notably Ubuntu).

- `playbooks/02-critical-path.yml` runs the role but **skips baseline creation** (`fim_aide_initialize_db: false`).
- Use `playbooks/05-fim-baseline.yml` to create baselines ahead of time.

## Discord integration

The check script will use the auditd role's sender if present:

`/usr/local/bin/ccdc-audit-alerts/send-discord-alert.py`

If it isn't present/executable, the script logs to syslog via `logger`.
