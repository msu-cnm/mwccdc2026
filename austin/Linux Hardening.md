***
# General Guidelines
***
1. Fix firewall rules
3. Search for backdoors
4. Search for reverse shells
5. Ensure best practices are observed
6. https://github.com/msu-cnm/cyberteam/
7. Remember to make backups of config files before editing
***
## Default Port Numbers
***

| Service         | Port#                                  |
| --------------- | -------------------------------------- |
| DNS             | 53 (853 for secure, 5353 for mDNS)     |
| NTP             | 123 udp                                |
| HTTP/HTTPS      | 80/443 tcp                             |
| DHCP            | 67, 68 udp                             |
| SMTP            | 25, 587, 465 tcp                       |
| POP3            | 110 for unencrypted, 995 for encrypted |
| FTP             | 20, 21                                 |
| AD requirements | 49152:65535                            |



## Default Firewalls
***
NOTE: SNMP MUST BE ALLOWED
#### Ubuntu
* ufw 

| Command                                                                               | Description      |
| ------------------------------------------------------------------------------------- | ---------------- |
| sudo ufw enable                                                                       | enable ufw       |
| sudo ufw status (numbered/verbose)                                                    | status and rules |
| sudo ufw allow SERVICE                                                                | allow rule       |
| sudo ufw deny SERVICE<br>OR<br>sudo ufw deny proto (udp/tcp) from any to any port (#) | deny rule        |
| sudo ufw delete RULE                                                                  | delete rule      |
| sudo ufw reload                                                                       | reload ufw       |

#### RH and CentOS
* firewall-cmd (firewalld)

| Switch                                  | Description                 |
| --------------------------------------- | --------------------------- |
| --state                                 | check if firewall is active |
| --get-active-zones                      | list all active zones       |
| --zone=ZONE --add-service=SERVICE       | allow a service             |
| --zone=ZONE --remove-service=SERVICE    | deny a service              |
| --zone=ZONE --add-port=NUMBER/(tcp/udp) | allow a port                |

## Default File Locations
***

| File                                             | Location                                            |
| ------------------------------------------------ | --------------------------------------------------- |
| SSH Config                                       | ~/.ssh OR /etc/ssh<br>%programdata%\ssh\sshd_config |
| SSH Authorized Keys                              | .ssh/authorized_keys                                |
| cron.allow (what users can schedule cron jobs)   | /etc/cron.allow                                     |
| cron.deny (what users cannot schedule cron jobs) | /etc/cron.deny                                      |

### SSH Config
	Make sure to include the following lines
	PubkeyAuthentication yes
	For the following line to work you need host keys in /etc/ssh/ssh_known_hosts
	HostbasedAuthentication yes
	PermitRootLogin no
	MaxAuthTries 20
	AllowTcpForwarding no
	GatewayPorts no
	Remember SSH server needs to be reloaded after making changes, run:
	systemctl reload sshd



### SUDO
***
Adding and removing users
	`sudo deluser username sudo`
	`sudo adduser username sudo`
/etc/sudoers
	`modified with visudo`

### Permissions
***
* Display users and privilages
	`cat /etc/passwd
* Display groups
	`cat /etc/group
* Add/remove users and groups
	`groupadd
	`useradd
	`userdel -rf
	`groupdel`
* Add/remove user's groups
	`usermod -a -G <groupName> <userName>
	`deluser <user> <group>`
* View groups a user is in
	`groups <userName>`
## Commands
***
### watch
	Used to rerun a command every 2 seconds
### who
	Used to show who is currently logged into a system
### netstat
Typical usage: netstat -vatupn or watch netstat -vatupn for continuous monitoring

| Switch | Description                         |
| ------ | ----------------------------------- |
| -n     | numeric (don't translate hostnames) |
| -a     | All connections and ports           |
| -p     | adds name of executable to output   |
| -v     | verbose                             |
| -c     | continuous                          |
### lsof
	used to list open files
### members
	used to show the members of a specified group

### systemctl

| Command                                   | Descrioption               |
| ----------------------------------------- | -------------------------- |
| systemctl list-units --type=service --all | List all running services  |
| systemctl status NAME                     | Check status of service    |
| systemctl start NAME                      | Start a service            |
| systemctl stop NAME                       | Stop a service             |
| systemctl enable --now                    | Start and Enable a service |


## Tools
***

### Crontab

| Switch | Description          |
| ------ | -------------------- |
| -u     | specify user         |
| -l     | list current crontab |
| -e     | edit crontab         |

### Nmap
	Typical usage: sudo nmap -sV -O -Pn IP-ADDRESS

| Switch | Description                                                    |
| ------ | -------------------------------------------------------------- |
| -p     | Check a specific tcp port                                      |
| -Pn    | Scan even if pings fail                                        |
| -p-    | Scan all ports                                                 |
| -Pn    | Scan even if pings fail                                        |
| -sV    | Enumerate ports to determine service applicaitons and versions |


### Tmux

| Prefix         | Description          |
| -------------- | -------------------- |
| prefix ctrl+b  | default prefix       |
| prefix c       | new window           |
| prefix 1       | switch to window (1) |
| prefix shift+% | split vertically     |
| prefix shift+" | split horizontally   |
| prefix ->      | switch to right pane |
| prefix  [      | scroll mode          |
### Vim

| Command | Description     |
| ------- | --------------- |
| x       | cut character   |
| dd      | cut entire line |
| yw      | copy word       |
| yy      | copy full line  |
| p       | paste           |
| :1      | go to line 1    |
| :$      | go to last line |

#### Whowatch
	Used to monitor who is on the system / stop processes / stop access
	sudo apt/dnf/yum install whowatch
	

| Shortcut            | Action                           |
| ------------------- | -------------------------------- |
| enter               | selected users process tree      |
| t                   | all system processes (init tree) |
| while in tree mode: |                                  |
| enter               | go back to users list            |
| o                   | show process owners              |
| Ctrl+I              | send INT signal                  |
| Ctrl+K              | send KILL signal                 |
| Ctrl+T              | Send TERM signal                 |

### fail2ban
	Used to prevent bruteforce attacks on ssh, apache, etc.
	sudo apt/dnf/yum install fail2ban
	systemctl status fail2ban

### clamAV
	opensource AV for linux mail servers
	sudo apt/dnf/yum install clamav clamav-daemon
	sudo systemctl start clamav-freshclam
	sudo freshclam

### RKHunter
	searches for rootkits, backdoors, and local exploits
	sudo apt/dnf/yum install rkhunter
	sudo rkhunter --update
	run scan with: sudo rkhunter --check --skip-keypress

## Bash Scripting
***
Start Script with 
```bash
#!/usr/bin/env bash
set -euo pipefail
```
good luck, look it up lol
## Apache
***
#### Installing
##### Ubuntu/Debian
```
sudo apt install apache2
sudo service apache2 start
```
##### Fedora/CentOS/RedHat
```
sudo yum install httpd
sudo systemctl enable httpd
sudo systemctl start httpd
```
#### Hardening
* Should be running under www-data (restrict privileges)
* Config location
	`/etc/apache2/apache2.conf
	`/etc/httpd/httpd.conf
	`/etc/httpd/conf/httpd.conf
* In the config file:
	* ensure `<FilesMatch "^\.ht">` require all is set to denied
	* Under `<Directory /var/www/>` get rid of allow override and add the following lines
		`Options -Indexes`
		`ServerSignature off`
* In `/etc/apache2/conf-enabled/security.conf`:
	* Change set `ServerTokens Prod`
	* Uncomment `ServerSignature Off` and comment out `ServerSignature On`
	* 
* Change owner of .htaccess to www-data (if it exists)
	` sudo chown www-data:www-data .htaccess 
	if it exists you can also add Options -Indexes and ServerSignature off to it

# Docker
***
#### Commands

| Command                    | Description                         |
| -------------------------- | ----------------------------------- |
| docker ps                  | List running containers             |
| docker image ls            | List installed images               |
| docker pull IMAGE          | Download latest version of an image |
| docker run IMAGE           | Run an image                        |
| docker stop CONTAINER_NAME | Stop a container                    |
| docker logs CONTAINER_NAME | View container logs                 |


#### Best Practices
1. Keep host and docker up to date
2. Do not expose the Docker daemon socket
	* located in `/var/run/docker.sock`
	* owner should be root
	* Do not enable tcp docker daemon socket
	* Do not expose /var/run/docker.sock to containers
3. Set an unprivileged user for containers
	* Use `docker run -u UID IMAGE`
	* OR add `USER myuser` line to Dockerfile
4. Limit capabilities
	* Do not run containers with --privileged tag
	* You can run containers with `--cap-drop all` but you need to add back necessary capabilities with `--cap-add CHOWN` for example
5. Prevent in-container priv esc
	* Always run images with --security-opt=no-new-privileges
6. Be mindful of inter-container connectivity
	* by default all docker containers can talk amongst eachother
	* `--icc=false can be used to disable this but is not recommended`
	* If time permits create a specific network configuration
7. Use Linux Security Module (seccomp, AppArmor, SELinux)
	* Do not disable default security profile
8. Limit resources
	* `--restart=on-failure:<number_of_restarts>` set a maximum number of restarts
	* `--ulimit nofile=<number>` set maximum number of file descriptors
	* `--ulimit nproc=<number>` set maximum number of processes
9. Set filesystem and volumes to read-only
	* run containers with `--read-only` flag
	* If an application needs to save something temporarily, use `--tmpfs /tmp`
10. Scan containers (ThreatMapper)
11. Run docker in rootless mode
	* If not already done, this will take a lot of work. Probably not worth the time
12. Utilize docker secrets for sensitive data management
	* `docker secret create my_secret /path/to/super-secret-data.txt`
	* `docker service create --name web --secret my_secret nginx:latest`

### SYSLOG
***
Client Configuration:
	`sudo apt install rsyslog`
	`sudo vim /etc/rsyslog.conf`
	add syslog server address
	`*. * @@172.20.241.20:514`
	save changes and restart
	`sudo systemctl restart rsyslog`
	Optionally apache logs can also be sent to SPLUNK by adding the following to `/etc/apache2/apache2.conf`
	``
### SNMP Linux
***
`sudo apt install snmp snmpd
`sudo vim /etc/snmp/snmpd.conf`
