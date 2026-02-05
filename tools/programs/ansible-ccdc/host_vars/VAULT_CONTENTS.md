# Vaulted Variables – host_vars

This directory contains per-host Ansible Vault files used to store secrets securely.
This document describes categories of data stored here (not values).

## Stored Here
- Per-host credentials (initial and post-rotation)
- Application credentials (e.g., Splunk admin)

## Notes
- Non-secret host configuration (profiles, paths, priorities) should live in normal host_vars files.
- Values are not stored in plaintext in the repository.
