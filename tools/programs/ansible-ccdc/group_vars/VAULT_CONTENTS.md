# Vaulted Variables – group_vars

This directory contains Ansible Vault files used to store shared secrets securely.
This document describes what categories of data live here (not their values).

## Stored Here
- Discord / alerting webhooks
- Shared admin passwords used for initial password rotation

## Variables
- vault_discord_webhook_url
- vault_default_password

## Notes
- No secrets are stored in plaintext in the repository.
- These values do not define network layout (no IPs, routes, or hostnames).
- Some values may also be supplied via environment variables during execution.
