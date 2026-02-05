# common_notify

Purpose:
- Send notifications for significant automation events

Used by:
- critical-path and supporting playbooks

Changes:
- Sends alerts to configured notification endpoints

Key Inputs (vars):
- vault_discord_webhook_url

Notes:
- Does not make system changes
- Safe to run multiple times
