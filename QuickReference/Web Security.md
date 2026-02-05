# HTTP Security

1. Check out `/etc/httpd/conf/httpd.conf`

2. Look for security holes
   ```bash
   # Make sure user/group are set to no-privilege user like apache (You can check /etc/passwd for a service account to use or make one)
   User apache
   Group apache
   
   # NOTE: If you need to create a no privilege user
   # useradd -M USERNAME
   # usermod -L USERNAME
   
   <Directory "SOMETHING">
   	AllowOverride None ## This should always be none
   </Directory>
   
   
   <Directory /PATH/TO/WEBDIR/wp-admin>
       # allow access from one IP and an additional IP range,
       # and block everything else
       Require ip 1.2.3.4
       Require ip 192.168.0.0/24
   </Directory>
   ```

   
