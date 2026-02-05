# Securing Windows Server 2019

## Active Directory

### Advanced Auditing
- Navigate to Group Policy Management (Server Manager > Tools > Group Policy Management)
- Right click Group Policy Objects and select New. Create a name.
- Right click the new GPO and select Edit.
- Computer Configuration > Policies > Windows Settings > Security Settings > Advanced Audit Policy Configuration
I selected the following:
- DS Access
    - Audit Directory Service Access - Success and Failure
- Logon/Logoff
    - Audit Account Lockout - Success and Failure
    - Audit Logoff - Success and Failure
    - Audit Logon - Success and Failure
    - Audit Other Logon/Logoff Events - Success and Failure
- Policy Change
    - Audit Audit Policy Change - Success and Failure
    - Audit Authentication Policy Change - Success and Failure
    - Audit Authorization Policy Change - Success and Failure
    - Audit Filtering Platform Policy Change - Success and Failure
    - Audit Other Policy Change Events - Success and Failure
- Privilege Use
    - Audit Sensitive Privelege Use - Success and Failure
- System
    - A udit Security State Change - Success and Failure
    - Audit System Integrity - Success and Failure

After updating policies, from PowerShell enter the following:
```plaintext
gpupdate /Force
```


### Group Policy Management
By default the server has a GPO that disables password complexity. Delete this and create a new GPO (I titled my Enforce Password Complexity). To set password policies, right click the created GPO and go to Edit. From the Group Policy Management Editor:
- Computer Configuration > Policies > Windows Settings > Security Settings > Account Policies > Password Policy

There are multiple policy settings here that can be modified. I did the following:
- Enforce password history - 5 passwords remembered
- Maximum password age - 60 days
- Minimum password age - 30 days
- Minimum password length - 16 characters
- Password must meet complexity requirements - Enabled
- Store passwords using reversible encryption - Disabled

Additionally, you can create account lockout policies.
- Computer Configuration > Policies > Windows Settings > Security Settings > Account Policies > Account Lockout Policy

After updating policies, from PowerShell enter the following:
```plaintext
gpupdate /Force
```
## DNS

### Verify DNS forwarders
- From Server Manager, Tools > DNS
- Right-click server, and go to Properties
- Navigate to Forwarders tab and select Edit...
- Two IPs do not resolve. Delete these.
- Add the following:
    - 8.8.8.8 (Google)
    - 8.8.4.4 (Secondary Google)
    - 1.1.1.1 (CloudFlare)
    - 1.0.0.1 (Secondary CloudFlare)

### Configure Network Adapter
- Navigate to Control Panel > Network and Internet > Network and Sharing Center and click Ethernet (next to Connections)
- Select Properties
- Double click IPv4
- Verify the following:
    - IP address: 172.20.242.200
    - Subnet mask: 255.255.255.0
    - Default gateway: 172.20.242.254 (Should be Palo Alto)
    - Preferred DNS server: 127.0.0.1
    - Alternate DNS server: 8.8.8.8
- Press OK
- Optional: Disable IPv6
- Open PowerShell
- Run the following commands:
```plaintext
ipconfig /flushdns
net stop dns
net start dns
```
- Verify DNS resolution
```plaintext
nslookup google.com
```

## Log Forwarding to Splunk
- Download Splunk Universal Forwarder - https://www.splunk.com/en_us/download/universal-forwarder.html
- Follow download steps
- Install Universal Forwarder
    - During setup, set username and password. Additionally, when promted for the receiving indexer, enter the IP address of the Splunk server (172.20.241.20) and the port (default is 9997)
- Enter the following in Command Prompt (Admin)
```plaintext
cd "C:\Program Files\SplunkUniversalForwarder\bin"
.\splunk.exe add monitor "C:\Windows\System32\winevt\Logs\*.evtx" -auth admin:<password>
```


