## <u>**Setting up Postfix with LDAP and Active Directory**</u>

------

**DNS CONFIGURATION**

1. Go into forward lookup zones and select your domain
2. Create a new A record for mail server (ex. `Host`: fedora)
   * FQDN for A record becomes `fedora.domain.com`
3. Create a new MX record for mail server
   * Leave `Host or child domain` blank
   * `Fully qualified domain name (FQDN):` is just your domain
   * `Fully qualified domain name (FQDN) of mail server:` becomes <u>hostname.domain.com</u> (ex. fedora.domain.com)
   * `Mail server priority` can be left at 10
4. Use `nslookup` to check to make sure everything is setup correctly and points to the correct IP address
   * Ex. `nslookup fedora.domain.com`

**ACTIVE DIRECTORY CONFIGURATION**

1. Create a new <u>user account</u> to be used for LDAP authentication
   * Make sure the user has a <u>non-expiring</u> password and does not need to be changed at log in (make it a strong password).
   * Needs to have read access to user attributes in AD (this should be default but in locked down AD environments might need to be explicitly set).

**SERVICES RUNNING**

1. Make sure your Postfix service is running: `netstat -tnlp`
   * Postfix should be listening on port `25` and might look something like `0.0.0.0:25   LISTEN   PID/master`

**POSTFIX CONFIG (<u>main.cf</u>)**

* Possible path to config: <u>/etc/postfix/main.cf</u>

1. Set up hostname. (`hostname` command to get hostname on mail server)

   `myhostname = FQDN (ex. fedora.domain.com)`

2. Set the domain name (Look in DNS settings on AD server)

   `my domain = domain.com`

3. Make sure `myorigin` is set to `$mydomain`.

4. Set `inet_interfaces to `all`.

5. Set `inet_protocols` to listen only for `IPv4`.

6. Make sure `mydestination` is set to `$myhostname, localhost.$mydomain, localhost, $mydomain`.

7. Look at `mynetworks`.  Include `10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16` if needed.

8. `home_mailbox` should be set to `Maildir/` .

9. To get SMTP-Auth to work:

   * `virtual_mailbox_maps = ldap:/etc/postfix/ad_virtual_mailbox_maps.cf`
   * `smtpd_sender_login_maps = ldap:/etc/postfix/ad_sender_login_maps.cf`

   * `smtp_sasl_type = dovecot`
   * `smtp_sasl_path = private/auth`
   * `smtpd_sas_auth_enable = yes`
   * `smtpd_sasl_security_options = noanonymous`
   * `smtpd_sasl_local_domain = $myhostname`

**POSTFIX CONFIG (<u>ldap-alias.cf</u>)**

1. Set `server_host` to the host of your AD machine (I used the IP address)
   * Ex.` server_host = 192.168.1.0`
2. Set `bind` to `yes`
3. Set `bind_dn` to your newly created AD Authentication user with the proper OU's
   * Ex. `bind_dn = CN=postfixAuth,CN=Users,DC=domain,DC=com`
4. Set `bind_pw` to the password of your AD Authentication user
   * Ex. `bind_pw = supersecurepassword1234`
5. Set `search_base` to where the LDAP search will be performed
   * Ex. `serach_base = CN=users,DC=domain,dc=com`
6. Make sure `scope` is `sub`
7. `result_attribute` should be set to `uid`
8. `result_format` should be set to `%s/Maildir/`

**POSTFIX CONFIG (<u>ad_sender_login_maps.cf</u>)**

1. Set `server_host` to the host of your AD machine (I used the IP address)
   * Ex.` server_host = 192.168.1.0`
2. Set `bind` to `yes`
3. Set `bind_dn` to your newly created AD Authentication user with the proper OU's
   * Ex. `bind_dn = CN=postfixAuth,CN=Users,DC=domain,DC=com`
4. Set `bind_pw` to the password of your AD Authentication user
   * Ex. `bind_pw = supersecurepassword1234`
5. Set `search_base` to where the LDAP search will be performed
   * Ex. `serach_base = CN=users,DC=domain,dc=com`
6. Make sure `scope` is `sub`
7. `result_attribute` should be set to `userPrincipalName`

**POSTFIX CONFIG (<u>ad_virtual_mailbox_maps.cf</u>)**

1. Set `server_host` to the host of your AD machine (I used the IP address)
   * Ex.` server_host = 192.168.1.0`
2. Set `bind` to `yes`
3. Set `bind_dn` to your newly created AD Authentication user with the proper OU's
   * Ex. `bind_dn = CN=postfixAuth,CN=Users,DC=domain,DC=com`
4. Set `bind_pw` to the password of your AD Authentication user
   * Ex. `bind_pw = supersecurepassword1234`
5. Set `search_base` to where the LDAP search will be performed
   * Ex. `serach_base = CN=users,DC=domain,dc=com`
6. Set `result_atrribute` to `mail`
7. Set `result_format` to where the mail will be stored per user. Here mail will be stored in each user's home folder in /Maildir
   * Ex. `result_format = /home/%u/Maildir`

**MAIL TRANSFER AGENT**

1. Check to see which MTA is being used: `alternatives --config mta`
2. Select `postfix`

**DEBUGING**

* To check if LDAP is properly working use: `postmap -q user@domain.com ldap:/etc/postfix/ad_virtual_mailbox_maps.cf`
* To send a test email: `echo "Test Email" | mail -s "test" user@domain.com`
  * To check if it sent: `journalctl -u postfix --since "10 min ago"` or check the users directory: `ls -l /home/{user}/Maildir/new`