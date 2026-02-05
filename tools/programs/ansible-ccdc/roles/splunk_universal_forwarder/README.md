# splunk_universal_forwarder

## Purpose
Install, configure, and validate the **Splunk Universal Forwarder (UF)** on Linux endpoints
in a competition-safe, idempotent manner.

This role handles installation, configuration, service management, and
end-to-end validation of forwarding to the Splunk server.

## Used By
- `04-install-forwarders.yml`

## What This Role Does
- Resolves the Splunk receiver host and port
- Installs the Universal Forwarder package (RPM or DEB)
- Starts the forwarder and accepts the license (first run only)
- Enables boot-start (best effort)
- Configures `outputs.conf` to forward to the Splunk receiver
- Configures log inputs **only if the files exist**
- Restarts the forwarder only when configuration changes
- Performs deterministic validation (config + network + runtime)

## What This Role Does NOT Do
- Does **not** install the Splunk server
- Does **not** manage TLS or encrypted receivers
- Does **not** modify firewall rules
- Does **not** assume specific OS distributions beyond RPM/DEB families
- Does **not** require ansible_os_family (package manager is inferred)

## Receiver Resolution Logic
The receiver is determined in the following order:

1. `splunk_universal_forwarder_host` (explicit, preferred)
2. Inventory host named `splunk` (fallback, if enabled)

If no receiver can be resolved, the role fails fast.

## Inputs (Variables)

### Required / Core
- `splunk_universal_forwarder_port` (default: `9997`)
- `splunk_universal_forwarder_from_inventory` (default: `true`)

### Optional Overrides
- `splunk_universal_forwarder_host`
- `splunk_universal_forwarder_local_pkg`
- `splunk_universal_forwarder_validate_certs`
- `splunk_universal_forwarder_validate_network`
- `splunk_universal_forwarder_verbose`

### Log Inputs (Conditional)
These inputs are only configured if the files exist:
- `/var/log/audit/audit.log`
- `/var/log/auth.log` (Debian-based)
- `/var/log/secure` (RPM-based)

A canary log (`/var/log/ccdc_uf_canary.log`) is always created and monitored.

## Assumptions
- Target hosts are Linux
- SSH access and privilege escalation already work
- Splunk receiver is reachable on TCP/9997
- Vaulted credentials are already loaded by the playbook

## Validation Performed
- UF binary presence
- Correct service user (`splunkfwd` preferred, fallback to `splunk`)
- `outputs.conf` contains the expected receiver target
- Optional TCP connectivity test to the receiver
- UF runtime status check
- Canary log ingestion setup

## Notes
- Safe to re-run (fully idempotent)
- Designed for competition execution
- Fails fast on misconfiguration to avoid silent data loss
