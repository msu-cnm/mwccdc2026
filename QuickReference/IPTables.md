## IPTables

### List Rules

```bash
# List rules
iptables -n -L -v

# List rules AND show line numbers (useful when inserting rules)
iptables -n -L -v --line-numbers

# List rules for INPUT chain (incoming connections)
iptables -n -L -v INPUT
```



### Set Default Actions (Drop anything not allowed)

```bash
# Set default chain policies
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# Accept on localhost
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Allow established sessions to receive traffic
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
```



### Add / Delete Rules

```bash
# Allow port, adding rule to end of the list
iptables -A INPUT -p <protocol> --dport <Portnumber> -j ACCEPT
# Example: iptables -A INPUT -p tcp --dport 80 -j ACCEPT

# Allow port, inserting rule at specific line number
iptables -I INPUT <Line_Number> -p <protocol> --dport <Portnumber> -j ACCEPT
# Example (Insert at line 5): iptables -I INPUT 5 -p tcp --dport 80 -j ACCEPT

# Deny all traffic (should be at bottom of list)
iptables -A INPUT -p <protocol> --dport <Portnumber> -j ACCEPT

# Delete an existing rule
## List rules first to get line numbers
iptables -n -L -v INPUT --line-numbers
## Delete the line in question
iptables -D INPUT <Line_Number>
```



### Save Rules

```bash
# On Debian Based systems:

netfilter-persistent save

# On RedHat/CentOS/Fedora Based systems

service iptables save
```