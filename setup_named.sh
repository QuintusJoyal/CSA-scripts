#!/usr/bin/env bash

# BIND DNS Server Setup Script for CentOS
# Author: 5.H.4.D.0.W

DOMAIN_NAME="csa.sliit"   # Domain name
DNS_SUB_DOMAIN="ns1"  # DNS server sub domain
FORWARD_ZONE="$DOMAIN_NAME"   # Forward zone name
REVERSE_ZONE="69.69.69.in-addr.arpa"    # Reverse zone name
FORWARDERS="8.8.8.8; 8.8.4.4;"  # Forwarding DNS servers terminate with (;)
SERVER_ADDR="69.69.69.69;" # Interface address to listen on
SERVER_HOST_ID="69" # Host id for reverse zone
MAIL_SERVER_ADDR="$SERVER_ADDR" # Mail server address
ALLOW_QUERY="69.69.69.0/24;" # Allow query from network or host

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

# Install BIND DNS server package
echo "Installing BIND DNS server..."
yum install -y bind bind-utils

# Configure named.conf
echo "Configuring named.conf..."
cat > /etc/named.conf <<EOF
options {
        listen-on port 53 { $SERVER_ADDR };

        directory       "/var/named";
        dump-file       "/var/named/data/cache_dump.db";
        statistics-file "/var/named/data/named_stats.txt";
        memstatistics-file "/var/named/data/named_mem_stats.txt";
        recursing-file  "/var/named/data/named.recursing";
        secroots-file   "/var/named/data/named.secroots";
        allow-query     { $ALLOW_QUERY };

        recursion yes;
        forwarders { $FORWARDERS };
        forward only;

        dnssec-enable yes;
        dnssec-validation yes;

        bindkeys-file "/etc/named.root.key";

        managed-keys-directory "/var/named/dynamic";

        pid-file "/run/named/named.pid";
        session-keyfile "/run/named/session.key";
};

logging {
        channel default_debug {
                file "data/named.run";
                severity dynamic;
        };
};

zone "$FORWARD_ZONE" {
        type master;
        file "$DOMAIN_NAME.zone";
        allow-query { $ALLOW_QUERY };
        notify yes;
};

zone "$REVERSE_ZONE" IN {
        type master;
        file "$DOMAIN_NAME.rzone";
        allow-query { $ALLOW_QUERY };
        notify yes;
};

zone "." IN {
        type hint;
        file "named.ca";
};

include "/etc/named.rfc1912.zones";
include "/etc/named.root.key";
EOF

# Create forward zone file
echo "Creating forward zone file for ${DOMAIN_NAME}..."
cat > /var/named/${DOMAIN_NAME}.zone <<EOF
\$ORIGIN $DOMAIN_NAME.
\$TTL 3D
@       IN      SOA     $DNS_SUB_DOMAIN.$DOMAIN_NAME. root.$DOMAIN_NAME. (
                        20240401
                        8H
                        2H
                        4W
                        1D )

@       IN      NS      $DNS_SUB_DOMAIN.$DOMAIN_NAME.
@       IN      MX      10 mail.$DOMAIN_NAME.
@       IN      TXT     "CSA Assignment Server"
@       IN      A       $SERVER_ADDR
mail    IN      A       $MAIL_SERVER_ADDR
www     IN      A       $SERVER_ADDR
$DNS_SUB_DOMAIN     IN      A       $SERVER_ADDR
EOF

# Create reverse zone file
echo "Creating reverse zone file for ${DOMAIN_NAME}..."
cat > /var/named/${DOMAIN_NAME}.rzone <<EOF
\$ORIGIN $REVERSE_ZONE.
\$TTL 3D
@       IN      SOA     $DNS_SUB_DOMAIN.$DOMAIN_NAME. root.$DOMAIN_NAME. (
                        20240401
                        8H
                        2H
                        4W
                        1D )
@       IN      NS      $DNS_SUB_DOMAIN.$DOMAIN_NAME.
$SERVER_HOST_ID      IN      PTR     $DOMAIN_NAME.
EOF

# Set ownership and permissions for zone files
chown named:named /var/named/${DOMAIN_NAME}.*
chmod 640 /var/named/${DOMAIN_NAME}.*

# Configure firewall for DNS
echo "Configuring firewall for DNS..."
firewall-cmd --zone=public --add-service=dns --permanent
firewall-cmd --reload

# Start and enable named service
echo "Starting BIND DNS server..."
systemctl start named
systemctl enable named

echo "BIND DNS server setup complete."

