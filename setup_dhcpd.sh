#!/usr/bin/env bash

# DHCP Server Setup Script for CentOS
# Author: 5.H.4.D.0.W

INTERFACE="eth0"  # Interface to listen on
SUBNET_ADDR="69.69.69.0"  # Subnet address
SUBNET_MASK="255.255.255.0" # Subnet mask
ROUTER="69.69.69.69"  # Router address
BROADCAST_ADDR="69.69.69.255" # Broadcast address
DHCP_ADDR_RANGE="$ROUTER $BROADCAST_ADDR" # Range of address in dhcp pool 
DOMAIN_NAME="csa.sliit" # Domain name
DOMAIN_NAME_SERVER="ns1.$DOMAIN_NAME" # Domain name server

# Check if script is run as root
if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root" 
  exit 1
fi

# Check if OS is CentOS
if [ ! -f /etc/redhat-release ]; then
  echo "This script is intended for CentOS only"
  exit 1
fi

# Check CentOS version
centos_version=$(grep -oE '[0-9]+\.[0-9]+' /etc/redhat-release)
if (( $(echo "$centos_version >= 7.0" | bc -l) )); then
  echo "CentOS version $centos_version is supported"
else
  echo "CentOS version $centos_version is not supported"
  exit 1
fi

# Install DHCP server package
echo "Installing DHCP server..."
yum install -y dhcp

# Configure DHCP server
echo "Configuring DHCP server..."
cat > /etc/dhcp/dhcpd.conf <<EOF
authoritative;

log-facility local7;

subnet $SUBNET_ADDR netmask $SUBNET_MASK {
  interface $INTERFACE;
  range $DHCP_ADDR_RANGE;
  option domain-name-servers ${DOMAIN_NAME_SERVER};
  option domain-name "$DOMAIN_NAME";
  option routers $ROUTER;
  option broadcast-address $BROADCAST_ADDR;
  default-lease-time 600;
  max-lease-time 7200;
}
EOF

# Firewall configuration for DHCP
echo "Configuring firewall for DHCP"
firewall-cmd --zone=public --add-service=dhcp --permanent
firewall-cmd --reload

# Start DHCP server
echo "Starting DHCP server..."
systemctl start dhcpd
systemctl enable dhcpd

echo "DHCP server setup complete."

