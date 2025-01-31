#!/bin/bash

if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <IP-address> <domain> <tomcat_version>. Example: 192.168.0.0 example.com 10.1.34"
    exit 1
fi

IP="$1"
DOMAIN="$2"
TOMCAT_VERSION="${3//v/}"

IP_REGEX='^([0-9]{1,3}\.){3}[0-9]{1,3}$'
DOMAIN_REGEX='^([a-zA-Z0-9]+(-[a-zA-Z0-9]+)*\.)+[a-zA-Z]{2,}$'
TOMCAT_VERSION_REGEX='^(10|v10)(\.[0-9]+)*$'

if [[ ! $IP =~ $IP_REGEX ]]; then
    echo "Invalid IP address: $IP. Example: 192.168.0.0"
    exit 1
fi

if [[ ! $DOMAIN =~ $DOMAIN_REGEX ]]; then
    echo "Invalid domain: $DOMAIN. Example: example.com"
    exit 1
fi

if [[ ! $TOMCAT_VERSION =~ $TOMCAT_VERSION_REGEX ]]; then
    echo "Invalid Tomcat version: $TOMCAT_VERSION. Example: 10.1.34"
    exit 1
fi

echo "Updating system and installing required packages..."
sudo apt update && sudo apt install -y apache2 default-jdk postgresql snapd software-properties-common wget locales

echo "Updating locales..."
sudo locale-gen en_US.UTF-8
sudo update-locale LANG=en_US.UTF-8

echo "Installing Certbot..."
sudo snap install --classic certbot
sudo ln -s /snap/bin/certbot /usr/bin/certbot

echo "Configuring Apache..."
sudo a2enmod proxy_http

APACHE_CONF="/etc/apache2/sites-available/$DOMAIN.conf"
sudo tee "$APACHE_CONF" > /dev/null <<EOF
<VirtualHost *:80>
    ServerName $DOMAIN
    ServerAlias www.$DOMAIN
    ProxyRequests Off
    ProxyPreserveHost On
    ServerAdmin admin@$DOMAIN
    DocumentRoot /var/www/html
    ProxyPass / http://$IP:8080/
    ProxyPassReverse / http://$IP:8080/
    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF

sudo a2ensite "$DOMAIN"
sudo a2dissite 000-default.conf
sudo systemctl restart apache2

echo "Updating /etc/hosts..."
echo "$IP $DOMAIN" | sudo tee -a /etc/hosts > /dev/null

echo "Installing Tomcat $TOMCAT_VERSION..."
sudo groupadd tomcat
sudo useradd -s /bin/false -g tomcat -d /opt/tomcat tomcat

TOMCAT_TAR="apache-tomcat-$TOMCAT_VERSION.tar.gz"
wget "https://downloads.apache.org/tomcat/tomcat-10/v$TOMCAT_VERSION/bin/$TOMCAT_TAR" -P /tmp

sudo mkdir -p /opt/tomcat
sudo tar xf "/tmp/$TOMCAT_TAR" -C /opt/tomcat
sudo ln -s "/opt/tomcat/apache-tomcat-$TOMCAT_VERSION" /opt/tomcat/latest

sudo chown -RH tomcat: /opt/tomcat/latest
sudo chmod +x /opt/tomcat/latest/bin/*.sh

echo "Creating systemd service for Tomcat..."
TOMCAT_SERVICE="/etc/systemd/system/tomcat.service"
sudo tee "$TOMCAT_SERVICE" > /dev/null <<EOF
[Unit]
Description=Apache Tomcat Web Application Container
After=network.target

[Service]
Type=forking

Environment="JAVA_HOME=/usr/lib/jvm/default-java"
Environment="CATALINA_PID=/opt/tomcat/latest/temp/tomcat.pid"
Environment="CATALINA_HOME=/opt/tomcat/latest/"
Environment="CATALINA_BASE=/opt/tomcat/latest/"
Environment="CATALINA_OPTS=-Xms512M -Xmx1024M -server -XX:+UseParallelGC"
Environment="JAVA_OPTS=-Djava.awt.headless=true -Djava.security.egd=file:/dev/./urandom"

ExecStart=/opt/tomcat/latest/bin/startup.sh
ExecStop=/opt/tomcat/latest/bin/shutdown.sh

User=tomcat
Group=tomcat
UMask=0007
RestartSec=10
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable tomcat
sudo systemctl start tomcat

echo "Configuring PostgreSQL..."
sudo -u postgres psql -c "CREATE USER ktor WITH PASSWORD 'ktor';"
sudo -u postgres psql -c "CREATE DATABASE demodatabase OWNER ktor;"
sudo -u postgres psql demodatabase -c "CREATE TABLE demotable (id serial, key TEXT NOT NULL, value TEXT NOT NULL);"
sudo -u postgres psql demodatabase -c "INSERT INTO demotable (key, value) VALUES ('key1', 'value1');"
sudo -u postgres psql demodatabase -c "GRANT ALL PRIVILEGES ON TABLE demotable TO ktor;"
sudo -u postgres psql demodatabase -c "GRANT ALL PRIVILEGES ON SEQUENCE demotable_id_seq TO ktor;"

echo "Configuring SSL certificates..."
sudo certbot --apache -d "$DOMAIN" --non-interactive --agree-tos -m admin@$DOMAIN

echo "Restarting Apache and Tomcat..."
sudo systemctl restart apache2 tomcat

DEMO_TXT="/home/demo.txt"
sudo tee "DEMO_TXT" > /dev/null <<EOF
txt file
EOF

cd /opt/kursx-server
./gradlew war

echo "Done! Server configured for domain $DOMAIN and IP $IP with Tomcat $TOMCAT_VERSION. You can go to https://$DOMAIN now."
