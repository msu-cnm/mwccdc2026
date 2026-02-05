# common_preflight

Purpose:
- Perform pre-flight checks before making system changes

Used by:
- critical-path and supporting playbooks

Changes:
- None (validation only)

Key Inputs (vars):
- (none)

Notes:
- Fails early if prerequisites are missing
- If this role fails, stop and fix access or variables before proceeding
