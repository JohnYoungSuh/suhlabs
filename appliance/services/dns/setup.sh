#!/bin/bash
# DNS Server Setup (dnsmasq)
set -e

echo "Installing dnsmasq..."
apt-get update
apt-get install -y dnsmasq

echo "Configuring dnsmasq..."
cat > /etc/dnsmasq.d/aiops.conf <<EOF
# DNS Configuration
domain-needed
bogus-priv
no-resolv
no-poll

# Upstream DNS servers
server=1.1.1.1
server=8.8.8.8

# Local domain
local=/home.local/
domain=home.local

# DHCP range (optional)
# dhcp-range=192.168.1.50,192.168.1.150,12h

# Listen on specific interface
interface=eth0
EOF

echo "Enabling and starting dnsmasq..."
systemctl enable dnsmasq
systemctl restart dnsmasq

echo "DNS server setup complete!"
