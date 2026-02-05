# Services

### Checking the Status of Services 

- `service --status-all | grep running`
- `chkconfig --list` list services enabled on boot
- `initctl list` check services running in SystemV
- `systemctl status <serviceName>`

### Starting & Stopping Services 

- `systemctl stop <service-name>`
- `systemctl disable <service-name>`
- `systemctl enable <service-name>`
- `systemctl start <service-name>`