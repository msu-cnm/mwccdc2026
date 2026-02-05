# splunk_harden

## Purpose
Apply **safe, Phase-2 hardening** to the Splunk server without breaking
forwarder ingestion or scoring.

This role focuses on permissions, ownership, and runtime sanity checks —
not deep security reconfiguration.

## Used By
- `03-configure-splunk.yml`

## What This Role Does
- Ensures Splunk is running
- Waits for management (8089) and receiver (9997) ports
- Applies secure ownership and permissions to existing config files
- Restarts Splunk only when file permissions change

## What This Role Does NOT Do
- Does **not** enable TLS for receivers
- Does **not** modify authentication settings
- Does **not** disable services or ports
- Does **not** deploy dashboards or forwarders
- Does **not** manage indexes or inputs

## Inputs (Variables)
- `splunk_receiver_port` (default: 9997)
- `splunk_mgmt_port` (default: 8089)

## Assumptions
- Splunk is already installed
- Initial configuration is complete
- Forwarders are expected to continue sending data uninterrupted

## Notes
- This role is intentionally conservative
- Designed to be safe during competition execution
- Avoids changes that could impact scoring or ingestion
