#!/usr/bin/env bash

# Nagios Server Setup Script for CentOS
# Author: 5.H.4.D.0.W

$HT_PASSWD="1234"

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

# Install required packages
echo "Installing required packages..."
yum install -y httpd \
  php \
  php-cli \
  gcc \
  glibc \
  glibc-common \
  gd \
  gd-devel \
  net-snmp \
  openssl-devel \
  wget \
  unzip

# Create Nagios web user and group
echo "Creating Nagios web user and group..."
useradd nagios
usermod -a -G nagcmd nagios
usermod -a -G nagios apache

# Download Nagios Core source code
echo "Downloading Nagios Core source code..."
cd /tmp
wget https://assets.nagios.com/downloads/nagioscore/releases/nagios-4.5.1.tar.gz
tar -zxvf nagios-4.5.1.tar.gz

# Compile and install Nagios Core
echo "Compiling and installing Nagios Core..."
cd nagios-4.5.1
./configure --with-command-group=nagcmd >/dev/null
make all >/dev/null
make install >/dev/null
make install-init >/dev/null
make install-config >/dev/null
make install-commandmode >/dev/null
/usr/bin/nagios -v /usr/local/nagios/etc/nagios.cfg  # Verify configuration

# Install Nagios web interface
echo "Installing Nagios web interface..."
make install-webconf >/dev/null
htpasswd -b -c \
  /usr/local/nagios/etc/htpasswd.users nagiosadmin  \
  "${HT_PASSWD}" # Set Nagios web admin password

# Install Nagios plugins
echo "Installing Nagios plugins..."
cd /tmp
wget http://www.nagios-plugins.org/download/nagios-plugins-2.4.9.tar.gz
tar -zxvf nagios-plugins-2.4.9.tar.gz
cd nagios-plugins-2.4.9
./configure --with-nagios-user=nagios \
  --with-nagios-group=nagios \
  --with-openssl >/dev/null

make >/dev/null
make install >/dev/null

# Firewall configuration for HTTP (port 80) and HTTPS (port 443)
echo "Configuring firewall for HTTP (port 80) and HTTPS (port 443)..."
firewall-cmd --zone=public --add-service=http --permanent
firewall-cmd --zone=public --add-service=https --permanent
firewall-cmd --reload

# Start and enable httpd and Nagios services
echo "Starting and enabling services..."
systemctl start httpd
systemctl enable httpd
systemctl start nagios
systemctl enable nagios

echo "Nagios server setup complete."

