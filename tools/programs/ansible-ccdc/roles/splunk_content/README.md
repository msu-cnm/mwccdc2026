# splunk_content

## Purpose
Deploy Splunk **UI content** required by the team, currently limited to dashboards.

This role uploads **SimpleXML dashboards** to Splunk via the REST API
(`/servicesNS/.../data/ui/views`).

## Used By
- `03-configure-splunk.yml`

## What This Role Does
- Reads SimpleXML dashboard files from the controller (`docs/`)
- Creates the dashboard if it does not exist
- Updates the dashboard only if the content has changed
- Uses Splunk’s management API (8089)

## What This Role Does NOT Do
- Does **not** deploy Dashboard Studio JSON
- Does **not** manage Splunk apps
- Does **not** manage saved searches, alerts, or indexes
- Does **not** restart Splunk

## Inputs (Variables)
- `vault_splunk_admin_password` (required)
- `splunk_dashboard_app` (optional, default: `search`)
- `splunk_dashboard_name` (optional, default: `ccdc_dashboard`)

## Assumptions
- Splunk is already installed and running
- Splunk management API (8089) is reachable locally
- Admin authentication is functional

## Notes
- Dashboard deployment is idempotent
- Authentication failures will hard-fail to avoid silent partial state
