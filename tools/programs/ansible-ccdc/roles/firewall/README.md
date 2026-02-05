# Firewall Hardening Role

## Overview

Profile-driven host-based firewall hardening for CCDC competition environments.

This role configures **UFW** (Ubuntu/Debian) or **firewalld** (Fedora/RHEL) depending on the host OS.
It enforces a **default-deny inbound policy**, allows only required services, and restricts sensitive ports to trusted internal networks.

The role is designed to be **competition-safe**:

* Does **not** change firewalld zones
* Does **not** remove existing services
* Does **not** surprise-enable firewalls unless explicitly configured
* Always keeps SSH accessible to prevent lockout

---

## Supported Platforms

* Ubuntu / Debian (UFW)
* Fedora / RHEL (firewalld)

Backend selection is automatic based on `ansible_os_family`.

---

## Design Principles

* Inventory is the source of truth
* Profiles define exposure, not ad-hoc rules
* SSH is always allowed first
* ICMP is always allowed (competition requirement)
* Sensitive services (e.g., Splunk) are **internal-only**
* Safe defaults, explicit overrides

---

## How It Works (High Level)

1. Detect firewall backend (ufw or firewalld)
2. Load optional host-specific firewall vars
3. Resolve the effective firewall profile
4. Apply:

   * Default policies
   * ICMP allow rules
   * Profile-based allowed ports
   * Internal-only restrictions for sensitive ports
5. Optionally apply:

   * SSH rate limiting
   * Logging
   * Kernel network hardening

---

## Firewall Profiles (Source of Truth)

This role is **profile-driven**.
You do **not** enable ports directly — profiles select from a central service catalog.

Profiles are defined in:

```
roles/firewall/defaults/main.yml
```

### Available Profiles

| Profile  | Purpose                                |
| -------- | -------------------------------------- |
| baseline | SSH only                               |
| ecom     | SSH + HTTP + HTTPS                     |
| webmail  | SSH + Web + Mail stack                 |
| splunk   | SSH + Web (Splunk ports internal-only) |

### Selecting a Profile (per host)

Set in `host_vars/<host>/firewall.yml`:

```yml
firewall_profile: splunk
```

---

## Service Catalog

The role maintains a central catalog of possible services (ports + protocols).
Profiles select from this catalog; they do **not** define ports inline.

Examples from the catalog:

* SSH (22/tcp)
* HTTP (80/tcp)
* HTTPS (443/tcp)
* SMTP (25/tcp)
* POP3 (110/tcp)
* Splunk (8000, 8089, 9997 — restricted)

---

## Internal-Only Ports

Some services must **never** be exposed publicly (e.g., Splunk).

These ports are allowed **only** from trusted internal CIDRs using:

* firewalld rich rules, or
* UFW `from_ip` rules

Trusted CIDRs are defined in:

```
group_vars/all/firewall.yml
```

Example:

```yml
firewall_internal_cidrs:
  - "172.20.242.0/24"
  - "172.20.240.0/24"
```

---

## Optional Host-Specific Services

Additional services can be appended per host:

```yml
firewall_additional_services:
  - name: mysql
    port: 3306
    proto: tcp
    comment: "MySQL (internal)"
```

These are appended to the profile allow list.

---

## ICMP Handling (Important)

ICMP echo-request and echo-reply are **always allowed**.

This is intentional and aligns with MWCCDC competition expectations.
ICMP blocking is **not supported** by this role.

---

## SSH Safety

* SSH is always allowed before other rules are applied
* Optional SSH rate limiting is supported
* Prevents accidental lockout during competition

Example:

```yml
firewall_enable_rate_limiting: true
firewall_ssh_rate_limit: "10/minute"
```

---

## Logging (Optional)

Firewall logging can be enabled:

```yml
firewall_enable_logging: true
firewall_log_denied: true
```

* UFW: uses `/var/log/ufw.log`
* Firewalld: logs via `journalctl`

---

## Kernel Network Hardening (Optional)

The role can optionally apply kernel-level protections:

* SYN cookies
* Disable IP forwarding
* Disable ICMP redirects
* Enable source address validation (rp_filter)

Disabled by default for safety.

---

## What This Role Does

### ✅ Applies

* Default deny inbound firewall policy
* Profile-based allowlist
* Internal-only port restrictions
* ICMP allow rules
* Optional SSH rate limiting
* Optional logging
* Optional kernel network hardening

### ❌ Does NOT Apply

* Network device firewall rules (Palo Alto, Cisco FTD)
* Application-layer firewalls (WAF, mod_security)
* IDS/IPS configuration
* SELinux / AppArmor policies
* Firewall zone changes (firewalld)

---

## Usage

### Typical Competition Usage

This role is normally executed via the **critical path playbook**:

```bash
ansible-playbook -i inventory/production.ini playbooks/02-critical-path.yml
```

Running it standalone is supported but not typical.

---

## Validation

### Verify Firewall State

```bash
# Ubuntu
ufw status verbose

# Fedora
firewall-cmd --state
firewall-cmd --list-all
```

### Verify Connectivity

* SSH still works
* Scored services respond
* Splunk ports reachable only from internal networks

---

## Troubleshooting

### Locked Out

* Revert snapshot (practice environment)
* Verify SSH is allowed in profile
* Re-run with `-vv` for context

### Service Not Reachable

* Confirm correct profile is set
* Verify internal CIDRs
* Check firewall summary output

---

## Dependencies

* `community.general`
* `ansible.posix`

Install with:

```bash
ansible-galaxy collection install community.general ansible.posix
```

---

## Status

**Competition-ready.**
Tested end-to-end via `02-critical-path.yml`.
