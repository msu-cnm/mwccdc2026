## **<u>Setting up Dovecot with Postfix & LDAP Authentication</u>**

------

<u>**DOVECOT CONFIGS **</u>

**dovecot.conf**

Found in: <u>/etc/dovecot/dovecot.conf</u>

1. Set `protocols` to whatever you need.
   * Ex. `protocols = pop3`

2. Make sure `listen` is set to `*` for IPv4 only

**10-auth.conf**

Found in: <u>/etc/dovecot/conf.d/10-auth.conf</u>

1. Allow plain text auth if needed `disable_plaintext_auth = no`
2. Add: `auth_mechanisms = plain login`

**10-main.conf**

1. Make sure `mail_location` matches postfix: `maildir:~/Maildir`

**10-master.conf**

1. Setup Postfix SMTP-auth:

   * `unix_listener /var/spool/postfix/private/auth {`

     `mode = 0666`

     `user = postfix`

     `group = postfix`

     `}`

**10-ssl.conf**

1. Change SSL if not required `ssl = no`

**<u>TESTING</u>**

1. Verify dovecot is running `systemctl status dovecot` and that its on the correct port `netstat -tnlp`
2. Use telnet to see if POP3 is working on port 110: `telnet localhost 110`
   * You should get something like: `+OK Dovecot ready.`
   * To simulate a POP3 session:
     1. USER {yourusername}
     2. PASS {yourpassword}
     3. You should see: `OK Logged in`
     4. List messages: `LIST`
     5. Retrieve a specific message: `RETR {number}`
     6. Type `QUIT`