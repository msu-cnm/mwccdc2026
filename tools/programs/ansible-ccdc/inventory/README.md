# Inventory

Inventories define host aliases and connection targets (`ansible_host`).

## Files

- `production.ini`  
  Competition inventory. May contain real competition IPs.  
  Contains **no credentials** (secrets live in Ansible Vault).

## Standards

- Use service-based aliases (`ecom`, `webmail`, `splunk`, `wkst`)
- Aliases are identifiers only; they do not rename systems
- Do not store credentials in inventory  
  See `group_vars/VAULT_CONTENTS.md` and `host_vars/VAULT_CONTENTS.md`
- Connection defaults are defined in `group_vars/*/connection.yml` (and optionally `ansible.cfg`)

## Competition Notes

- Do not change assigned IPs/hostnames unless directed by an inject
- If White Team guidance conflicts with this repo, follow White Team
