NOTE:  Everything I was finding was like 10 years old, so hopefully this works

# Server Setup

### Install NTP Server

```bash
sudo apt install ntpd
```

### Configure Server

```bash
nano /etc/ntp.conf

# Add IP of NTP server into this file:
server ntp.ubuntu.com iburst
server 127.0.0.1
fudge 127.0.0.1 stratum 10
```

### Start/Restart the NTP Server

```bash
sudo systemctl enable ntpd
sudo systemctl restart ntpd
```







# Client Setup

### Install NTP Client

```bash
sudo apt-get install ntp  # for Debian/Ubuntu
sudo yum install ntp      # for CentOS/RHEL
sudo dnf install ntp      # for Fedora
```

### Configure NTP

```bash
nano /etc/ntp.conf

# Add IP of NTP server into this file:
server 172.20.240.20 prefer
```

### Start/Restart the NTP Service

```bash
sudo systemctl enable ntpd
sudo systemctl restart ntpd
```

