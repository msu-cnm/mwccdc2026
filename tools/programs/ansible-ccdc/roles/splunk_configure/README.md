# splunk_configure

Purpose:
- Perform initial Splunk server configuration
- Validate admin authentication and management API access

Used by:
- `configure-splunk` playbook

Changes:
- Verifies Splunk management endpoint (8089)
- Validates admin credentials
- Enables receiving on required ports
- Applies baseline Splunk configuration

Key Inputs (vars):
- vault_splunk_admin_password
- vault_splunk_admin_initial_password
- splunk_mgmt_port

Notes:
- Assumes Splunk is already installed
- Does not deploy dashboards or content
- Do not run until credentials are verified
