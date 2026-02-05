## Firewalld

### Quick Steps

1. List firewall rules for the default zone
   `firewall-cmd --list-all`

2. If interface isn't listed, find which zone interface is in or use
   `firewall-cmd --get-active-zones`

3. If needed, rerun your rule list command
   `firewall-cmd --zone=WHATEVER --list-all`

4. Examine services/ports that are allowed & compare against what should be allowed

5. Remove/Add any ports/services as needed
   ```bash
   firewall-cmd [--zone=WHATEVER] --add-service=NAME
   firewall-cmd [--zone=WHATEVER] --add-port=NUMBER/PROTOCOL
   
   firewall-cmd [--zone=WHATEVER] --remove-service=NAME
   firewall-cmd [--zone=WHATEVER] --remove-port=NUMBER/PROTOCOL
   ```

6. When finished, save config
   `firewall-cmd --runtime-to-permanent`


### Setup

```bash
# install firewalld
apt install firewalld 
# enable service
systemctl enable firewalld.service 
# start service
systemctl start firewalld.service 
# get service status
systemctl status firewalld 
```



### List Rules and Available Services

```bash
# List rules
firewall-cmd --list-all

# List services
firewall-cmd --get-services

```

### Workign with Zones
```
# Show Zones
firewall-cmd --get-zones
## Or for more details
firewall-cmd --list-all-zones

# Create Zone
firewall-cmd --permanent --new-zone=zone-name
## NOTE: You have to reload after creating a zone to use it, so be sure to save before creating the zone
firewall-cmd --reload

# Delete Zone
firewall-cmd --permanent --delete-zone=zone-name
## NOTE: You have to reload after deleting a zone, so be sure to save before creating the zone
firewall-cmd --reload

# View default zone
firewall-cmd --get-default-zone

# Change default zone
firewall-cmd --set-default-zone zone-name

# Adding an interface to a zone
firewall-cmd --zone=zone-name --change-interface=<interface-name>

```


### Add / Delete Rules

```bash
# Allow a service
firewall-cmd --zone=public --add-service=<service> --permanent

# Block a service (Delete an existing rule)
firewall-cmd --zone=public --remove-service=<service> --permanent

# Allow a port
firewall-cmd --zone=public --add-port=<port>/<protocol> --permanent
# Example:  firewall-cmd --zone=public --add-port=80/tcp

# Block a port (Delete an existing rule)
firewall-cmd --zone=public --remove-port=<port>/<protocol> --permanent

```

### Save Configuration
`firewall-cmd --runtime-to-permanent`


### Reload Firewall (Apply changes)

```bash
# restart service (do this after changing rules)
systemctl restart firewalld.service 
```



### (Shouldn't need this, but just in case)

```bash
# stop the service
systemctl stop firewalld.service 
# dissable the service
systemctl dissable firewalld.service 
```

