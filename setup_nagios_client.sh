#!/usr/bin/env bash

# Nagios Client Setup Script for Fedora
# Author: 5.H.4.D.0.W

NAGIOS_SERVER="69.69.69.69"

# Check if script is run as root
if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root" >&2
  exit 1
fi

# Check if OS is Fedora
if [ ! -f /etc/fedora-release ]; then
  echo "This script is intended for Fedora only" >&2
  exit 1
fi

# Install required packages
echo "Installing required packages..."
yum install -y nrpe nagios-plugins-all

# Configure NRPE
echo "Configuring NRPE..."
sed -i 's/\(allowed_hosts=127.0.0.1\)/\1,'"$NAGIOS_SERVER"'/g' /etc/nagios/nrpe.cfg
sed -ie 's/#\(ssl_client_certs=0\)/\1/g' /etc/nagios/nrpe.cfg
sed -i 's/\(dont_blame_nrpe\)=0/\1=1/g' /etc/nagios/nrpe.cfg

systemctl enable nrpe
systemctl start nrpe

echo "Nagios client setup complete."

