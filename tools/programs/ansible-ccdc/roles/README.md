# Roles

This directory contains reusable Ansible roles used by the CCDC competition runbook.

Roles are **not executed directly**.  
They are invoked by numbered playbooks in `playbooks/`, which define the supported execution order.

---

## Critical Path Roles

These roles are applied early and are expected to be safe, fast, and repeatable under competition pressure.

- `ssh_hardening`  
  Hardens SSH configuration after key-based access is confirmed.

- `firewall`  
  Host-based firewall configuration (UFW / firewalld).

- `auditd`  
  Audit-based monitoring and security telemetry.

> The critical path is designed to stabilize and secure systems quickly
> without breaking access, scoring services, or White Team requirements.

---

## Splunk Roles

Roles related to the Splunk stack and log ingestion.

- `splunk_configure`  
  Initial Splunk server configuration and admin validation.

- `splunk_harden`  
  Safe baseline hardening for the Splunk service.

- `splunk_content`  
  Dashboard and UI content deployment via the Splunk REST API.

- `splunk_universal_forwarder`  
  Install and configure the Splunk Universal Forwarder on endpoints.

---

## FIM Roles

- `fim_aide`  
  AIDE-based file integrity monitoring (baseline creation + periodic checks).

---

## Design Notes

- Each role contains a README describing **what it actually does**
- Roles are written to be:
  - idempotent
  - competition-safe
  - host-aware (via `group_vars` / `host_vars`)
- Secrets and credentials are **never** stored in roles  
  (they are loaded from Ansible Vault at runtime)
- Do **not** change role behavior during competition unless directed by White Team

---

## Execution Model

- Roles are orchestrated through numbered playbooks
- Only playbooks listed in `playbooks/README.md` are considered validated
- Running individual roles directly is unsupported unless explicitly documented
