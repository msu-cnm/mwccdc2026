# Playbooks

This directory contains the **competition execution path**.
Playbooks are numbered in the intended run order.

Only the playbooks listed below are part of the expected day-of workflow.
Some are optional but useful during preparation.

---

## Run Order (Competition)

1. `00-bootstrap-keys.yml`  
   Deploy your SSH public key to targets (one-time).  
   Requires temporary password auth and `-k` when you run it.

2. `01-rotate-passwords.yml`  
   Rotate OS account passwords from initial/default → vaulted values.  
   Designed to fail safe (won’t rotate to an empty/unknown value).

3. `02-critical-path.yml`  
   Apply baseline hardening stack (SSH, firewall, auditd, validation, FIM config).  
   **Does not build AIDE baselines** (keeps runtime fast).

4. `03-configure-splunk.yml`  
   Configure Splunk server (mgmt/API sanity, receiver enablement, dashboard/content, safe hardening).

5. `04-install-forwarders.yml`  
   Install/configure Splunk Universal Forwarders (UF) on endpoints and validate forwarding.

---

## Optional (Preparation / When Time Allows)

- `05-fim-baseline.yml`  
  Build the initial **AIDE database baseline** on each host.  
  This can take several minutes per host (Ubuntu tends to be slower).  
  Recommended to run during prep/lab or when you have breathing room.

---

## Notes

- Inventory determines targets: `inventory/production.ini` (competition) or lab inventory if you keep one.
- Credentials are not stored in inventory; they live in Ansible Vault under `group_vars/` and `host_vars/`.
- If White Team guidance conflicts with this repo, follow White Team.
