 

---

 **BASELINE & DOCUMENTATION**

* Export default configuration (**`Device -> Setup -> Operations -> Export Named Configuration Snapshot running-config.xml`**)

* Check for updates (**`Device -> Software`**)

* Set firewall login-banner (**`Device -> Setup -> Management -> General Settings`**)
	* `set deviceconfig system login-banner "This sytem is for authorized use only. Unauthorized access is prohibited!"`

* Set firewall timezone (**`Device -> Setup -> Management -> General Settings`**)
	* `set deviceconfig system timezone America/Chicago`

* Establish Address Objects (**`Objects -> Addresses`**)
	* `set address <addressName> ip-netmask <IP>`

* Establish Service Objects (**`Objects -> Services`**)
	* `set service <serviceName> protocol <tcp/udp> port <port>`

| Server            | IP            |
| ----------------- | ------------- |
| Ubuntu_Server     | 172.20.242.30 |
| Ubuntu_Server_NAT | 172.25.27.11  |
| Fedora            | 172.20.242.40 |
| Fedora_NAT        | 172.25.27.39  |
| Splunk            | 172.20.242.20 |
| Splunk_NAT        | 172.25.27.9   |
| Ubuntu            | x.x.x.x       |

**LOG FORWARDING**

* Create a syslog forwarding method (**`Device -> Server Profiles -> Syslog`**)
	* `set shared log-settings syslog <name> server <serverName> server <IP> transport <TCP/UDP> port [514] format [BSD/LEGACY, IETF/STANDARD] facility [LOG_USER]`
* Create log-forwarding profile (**`Objects -> Log-Forwarding`**)
	* `set shared log-settings profiles <profileName> match-list <matchListName> log-type [threat] filter "All Logs" send-syslog <syslogProfile>`
	* `set shared log-settings profiles <sameProfileName> match-list <matchListName> log-type [traffic] filter "All Logs" send-syslog <syslogProfile>`

**ZONE PROTECTION**

* Create the zone protection profile (**`Network -> Network Profiles -> Zone Protection`**)
	* `set network profiles zone-protection-profile <name> scan 8001 action block`
	* `set network profiles zone-protection-profile <name> scan 8002 action block`
	* `set network profiles zone-protection-profile <name> scan 8003 action block`
	* `set network profiles zone-protection-profile <name> discard-unknown-option yes`
	* `set network profiles zone-protection profile <name> discard-malformed-option yes`
	* `set network profiles zone-protection profile <name> discard-loose-source-routing yes`
	* `set network profiles zone-protection profile <name> discard-strict-source-routing yes`

* Apply the zone protection profile (**`Network -> Network Profiles -> Zone Protection`**)
	* `set zone outside network zone-protection-profile <protectionProfile>`

**ADMIN SECURITY**

1. Check for current admin accounts (**`Device -> Administrators`**)
	* `show admins all`

- Create a new superuser (**`Device -> Administrators -> Add`**)
	- `set mgt-config users <newadmin> password`
	- `set mgt-config users <newadmin> permissions role-based superuser yes`

- Delete all other Admin accounts (**`Device -> Administrators`**)
	- `delete mgt-config users <OldAdminAccount>`

- Delete all other regular accounts (**`Device -> Local User Database -> Users`**)
- Expire all API Keys (**`Device -> Setup -> Management -> Authentication Settings`**)
  
* Show all active admin sessions & delete any that aren't supposed to be there
	* `show admins`
	* `delete admin-sessions username`
 
- Configure management interface (**`Device -> Setup -> Interfaces -> Management Interface -> Permitted IP Addresses`**)
	- `set deviceconfig system type static`
	- `set deviceconfig system ip-address <x.x.x.x>`
	- `set deviceconfig system netmask <x.x.x.x>`
	- `set deviceconfig system default-gateway <x.x.x.x>`
	- `set deviceconfig system permitted-ip <x.x.x.x>`

**SERVICES**

- Disable SSH and any other unwanted services (**`Device -> Setup -> Interfaces -> Management Interface -> Administrative Management Services`**)
	- `show system services`
	- `set deviceconfig system service disable-<service> yes disable-<service> yes`

- Delete any management profiles and create new (**`Network -> Network Profiles -> Interface Management`**)
	- `delete network profiles interface-management-profile <ProfileName>`
	- `set network profiles interface-management-profile <ProfileName> ping yes`

**INTERFACES** (**`Network -> Interfaces`**)

- Apply the management profiles to interfaces
	- `set network interface ethernet <interface> layer3 interface-management-profile <ProfileName>`
* Check the interface for correct static IP
	* `set network interface ethernet <interface> ip <ip>`

**NTP & DNS** (**`Device -> Setup -> Services`**)

* Set the NTP server 
	* `set deviceconfig system ntp-servers primary-ntp-server ntp-server-address <IP>`
	* `set deviceconfig system ntp-servers primary-ntp-server ntp-server-auth-type none`
* Set the DNS server
	* `set deviceconfig system dns-setting servers primary <IP>`

**NAT RULES** (**`Policies -> NAT`**)

* Show NAT Rules
	* `show rulebase nat`
* Delete any existing NAT Rules
	* `delete rulebase nat rules <natRuleName>` 
* Create new NAT Rules
	* `set rulebase nat rules <ruleName> nat-type ipv4 from <insideZone> to <outsideZone> source <IP> destination any service any source-translation static-ip translated-address <IP> bi-directional yes`

**SECURITY RULES** (**`Policies -> Security`**)

* Show Security Rules
	* `show rulebase security`
* Delete any existing Security Rules
	* `delete rulebase security rules <securityRuleName>`
* Create new Security Rules
	* `set rulebase security rules <ruleName> rule-type [universal] from <zone> to <zone> destination <IP> source <IP> application [ <application> <application> ] service [application-default] log-setting <logProfile> log-end [yes] action <allow> profile-setting group <ipsProfile>` 
	
| Server        | Applications                            |
| ------------- | ---------------------------------       |
| Ubuntu_Server | ssl, web-browsing                       |
| Fedora        | pop3, smtp, ssl (636), web-browsing     |
| Splunk        | splunk, syslog, ssl, web-browsing       |


- Check virtual router static route (default-route, destination: 0.0.0.0/0 interface: whatever outbound interface is, type: ip-address, value: vyos ip address

LOGS

- Enable system, config, and admin activity logs (Device -> Log Settings)

CONFIG NAT POLICIES, SECURITY POLICIES, SECURITY PROFILES

SAVE CONFIG, EXPORT CONFIG
