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

## Firewall
***

| Command                                                                               | Description      |
| ------------------------------------------------------------------------------------- | ---------------- |
| sudo ufw enable                                                                       | enable ufw       |
| sudo ufw status (numbered/verbose)                                                    | status and rules |
| sudo ufw allow SERVICE                                                                | allow rule       |
| sudo ufw deny SERVICE<br>OR<br>sudo ufw deny proto (udp/tcp) from any to any port (#) | deny rule        |
| sudo ufw delete RULE                                                                  | delete rule      |
| sudo ufw reload                                                                       | reload ufw       |

```
sudo ufw start
sudo ufw allow http
sudo ufw allow snmp
```

## File Locations
***

| File                                             | Location                                                                    |
| ------------------------------------------------ | --------------------------------------------------------------------------- |
| SSH Config                                       | `/etc/ssh/ssh_config` AND `/etc/ssh/sshd_config` (secure sshd_config first) |
| SSH Authorized Keys                              | /etc/ssh                                                                    |
| cron files                                       | /etc/cron*                                                                  |
| cron.allow (what users can schedule cron jobs)   | /etc/cron.allow (not present)                                               |
| cron.deny (what users cannot schedule cron jobs) | /etc/cron.deny (not present)                                                |

## SSH Config
***

In `/etc/ssh/sshd_config` and `/etc/ssh/ssh_config`
Include the following:
	`PubkeyAuthentication yes`
	For the following line to work you need host keys in /etc/ssh/ssh_known_hosts
	`HostbasedAuthentication yes`
	Comment out `UsePAM yes`
	`PermitRootLogin no`
	`MaxAuthTries 6`
	`AllowTcpForwarding no`
	`GatewayPorts no`
	Remember SSH server needs to be reloaded after making changes, run:
	systemctl reload sshd

### Permissions
***
Note: Users with admin and sudo group can use sudo
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

## Apache
***
#### Hardening
* Should be running under www-data (restrict privileges)
* Config location
	`/etc/apache2/apache2.conf
	`/etc/apache2/apache2.conf.in`
* In the config file:
	* ensure `<FilesMatch "^\.ht">` require all is set to denied
	* Under `<Directory /var/www/>` get rid of allow override and add the following lines
		`Options -Indexes`
		`ServerSignature off`
* In `/etc/apache2/conf-enabled/security.conf`:
	* Change set `ServerTokens Prod`
	* Uncomment `ServerSignature Off` and comment out `ServerSignature On`
* Web server root: /var/www/html
* Change owner of .htaccess to www-data (if it exists)
	` sudo chown www-data:www-data .htaccess 
	if it exists you can also add Options -Indexes and ServerSignature off to it
* In /etc/apache2/sites-enabled there is a file called openshop.conf
	* I don't think this is used in scoring and it may be okay to move the file somewhere else and disable the site.
* In /var/www/html zen-cart has been extracted but not implemented. Might be able to move this elsewhere

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


## GRUB
***
* `grub2-setpassword`

## /etc/login.defs
***
* Uncomment `SHA_CRYPT_MIN_ROUNDS 5000`
* change UMASK value to 027 

### /etc/pam.d/common-password
***
* add rounds=8 to the first password line:
	* `password [success=1 default=ignore] pam_unix.so obscure sha512 rounds=8`

## File Permissions
***
```
chmod 711 /etc/sudoers.d
chmod 440 /boot/grub/grub.cfg
chmod 640 /etc/crontab
chmod 750 /home/sysadmin
```


# Move on to avanced.md checklist on github
