#!/usr/bin/env bash

# Apache HTTP Server Setup Script with SSL for CentOS
# Author: 5.H.4.D.0.W

COUNTRY="LK"
STATE="Western province"
CITY="Malabe"
ORG="SLIIT"
DOMAIN_NAME="csa.sliit"
WEB_SERVER="69.69.69.69"

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

# Install Apache HTTP server package
echo "Installing Apache HTTP server (httpd)..."
yum install -y httpd mod_ssl

# Generate SSL certificate and key
echo "Generating self-signed SSL certificate and key..."
openssl req -new -newkey rsa:2048 -days 365 -nodes -x509 \
  -subj "/C=$COUNTRY/ST=$STATE/L=$CITY/O=$ORG/CN=$DOMAIN_NAME" \
  -keyout /etc/pki/tls/private/${DOMAIN_NAME}.key \
  -out /etc/pki/tls/certs/${DOMAIN_NAME}.crt

# Configure Apache to use SSL
echo "Configuring Apache to use SSL..."
cat > /etc/httpd/conf.d/ssl.conf <<EOF
Listen 443 https
SSLPassPhraseDialog exec:/usr/libexec/httpd-ssl-pass-dialog
SSLSessionCache         shmcb:/run/httpd/sslcache(512000)
SSLSessionCacheTimeout  300
SSLRandomSeed startup file:/dev/urandom  256
SSLRandomSeed connect builtin
SSLCryptoDevice builtin
<VirtualHost _default_:443>
  DocumentRoot "/var/www/html"
  ServerName $WEB_SERVER:443
  ErrorLog logs/ssl_error_log
  TransferLog logs/ssl_access_log
  LogLevel warn
  SSLEngine on
  SSLProtocol all -SSLv2 -SSLv3
  SSLCipherSuite HIGH:3DES:!aNULL:!MD5:!SEED:!IDEA
  SSLCertificateFile /etc/pki/tls/certs/${DOMAIN_NAME}.crt
  SSLCertificateKeyFile /etc/pki/tls/private/${DOMAIN_NAME}.key
  <Files ~ "\\.(cgi|shtml|phtml|php3?)$">
    SSLOptions +StdEnvVars
  </Files>
  <Directory "/var/www/cgi-bin">
    SSLOptions +StdEnvVars
  </Directory>
  BrowserMatch "MSIE [2-5]" \\
         nokeepalive ssl-unclean-shutdown \\
         downgrade-1.0 force-response-1.0
CustomLog logs/ssl_request_log \\
          "%t %h %{SSL_PROTOCOL}x %{SSL_CIPHER}x \\"%r\\" %b"
</VirtualHost>                                  
EOF

# Start and enable httpd service
echo "Starting Apache HTTP server (httpd)..."
systemctl start httpd
systemctl enable httpd

# Firewall configuration for HTTP (port 80) and HTTPS (port 443)
echo "Configuring firewall for HTTP (port 80) and HTTPS (port 443)..."
firewall-cmd --zone=public --add-service=http --permanent
firewall-cmd --zone=public --add-service=https --permanent
firewall-cmd --reload

echo "Apache HTTP server with SSL setup complete."

