#!/bin/bash

# Moodle 5.0 Production-Grade Installation Script for Rocky Linux
# Based on enterprise-level configuration with performance optimizations

set -e

# Configuration Variables
MOODLE_VERSION="5.0"
MOODLE_BRANCH="MOODLE_500_STABLE"
DB_NAME="moodledb"
DB_USER="moodleuser"
DB_PASS="PUTDBPASS@"  # CHANGE THIS!
DOMAIN=""  # Leave empty to use IP, or set your domain like "moodle.yourdomain.com"
MOODLE_DIR="/var/www/moodle"
PROJ_ROOT="/var/moodledata"
INSTALL_REDIS="no"  # Set to "yes" if you want Redis session handling

echo "================================"
echo "Moodle 5.0 Production Installation"
echo "================================"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root"
    exit 1
fi

# Detect server IP
SERVER_IP=$(hostname -I | awk '{print $1}')

echo "[1/12] Updating system packages..."
dnf update -y
dnf install -y epel-release

echo "[2/12] Installing PostgreSQL 15..."
dnf install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-9-x86_64/pgdg-redhat-repo-latest.noarch.rpm
dnf -qy module disable postgresql
dnf install -y postgresql15-server postgresql15-contrib
/usr/pgsql-15/bin/postgresql-15-setup initdb
systemctl enable postgresql-15
systemctl start postgresql-15

echo "[3/12] Configuring PostgreSQL database..."
sudo -u postgres psql -c "CREATE DATABASE ${DB_NAME};"
sudo -u postgres psql -c "CREATE USER ${DB_USER} WITH PASSWORD '${DB_PASS}';"
sudo -u postgres psql -c "ALTER DATABASE ${DB_NAME} OWNER TO ${DB_USER};"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} TO ${DB_USER};"

# Configure PostgreSQL to accept password authentication
sed -i 's/ident/md5/g' /var/lib/pgsql/15/data/pg_hba.conf
systemctl restart postgresql-15

echo "[4/12] Installing PHP 8.3 and required extensions..."
dnf install -y https://rpms.remirepo.net/enterprise/remi-release-9.rpm
dnf module reset php -y
dnf module enable php:remi-8.3 -y
dnf install -y php php-fpm php-cli php-common php-pgsql php-gd php-xml php-mbstring \
    php-curl php-zip php-intl php-soap php-xmlrpc php-opcache php-json php-sodium \
    php-pecl-zip php-ldap

echo "[5/12] Configuring PHP for production..."
sed -i 's/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/' /etc/php.ini
sed -i 's/upload_max_filesize = .*/upload_max_filesize = 200M/' /etc/php.ini
sed -i 's/post_max_size = .*/post_max_size = 200M/' /etc/php.ini
sed -i 's/max_execution_time = .*/max_execution_time = 300/' /etc/php.ini
sed -i 's/memory_limit = .*/memory_limit = 512M/' /etc/php.ini
sed -i 's/;max_input_vars = .*/max_input_vars = 5000/' /etc/php.ini
sed -i 's/^max_input_vars = .*/max_input_vars = 5000/' /etc/php.ini

# Enable OPcache for production
cat >> /etc/php.d/10-opcache.ini <<EOF

; Production OPcache settings
opcache.enable=1
opcache.memory_consumption=256
opcache.interned_strings_buffer=16
opcache.max_accelerated_files=10000
opcache.revalidate_freq=60
opcache.fast_shutdown=1
EOF

# Configure PHP-FPM
sed -i 's/user = apache/user = nginx/' /etc/php-fpm.d/www.conf
sed -i 's/group = apache/group = nginx/' /etc/php-fpm.d/www.conf
sed -i 's/listen = \/run\/php-fpm\/www.sock/listen = 127.0.0.1:9000/' /etc/php-fpm.d/www.conf

systemctl enable php-fpm
systemctl start php-fpm

echo "[6/12] Installing Nginx..."
dnf install -y nginx
systemctl enable nginx

echo "[7/12] Installing Git and downloading Moodle 5.0..."
dnf install -y git
cd /var/www
git clone -b ${MOODLE_BRANCH} https://github.com/moodle/moodle.git moodle

echo "[8/12] Creating separated Moodle data directories (production structure)..."
mkdir -p ${PROJ_ROOT}/data
mkdir -p ${PROJ_ROOT}/temp
mkdir -p ${PROJ_ROOT}/cache
mkdir -p ${PROJ_ROOT}/local
mkdir -p ${PROJ_ROOT}/data/filedir

chown -R nginx:nginx ${PROJ_ROOT}
chmod -R 2770 ${PROJ_ROOT}
chown -R nginx:nginx ${MOODLE_DIR}
chmod -R 755 ${MOODLE_DIR}

echo "[9/12] Installing Redis (optional)..."
if [ "$INSTALL_REDIS" = "yes" ]; then
    dnf install -y redis
    systemctl enable redis
    systemctl start redis
    REDIS_ENDPOINT="127.0.0.1"
    echo "Redis installed and enabled for session handling"
else
    REDIS_ENDPOINT=""
    echo "Skipping Redis installation (set INSTALL_REDIS='yes' to enable)"
fi

echo "[10/12] Creating production-grade Moodle config.php..."

# Determine the hostname/URL
if [ -z "$DOMAIN" ]; then
    HOSTNAME=""
    HOSTWITHPROTOCOL="http://${SERVER_IP}"
    SSLPROXY="false"
else
    HOSTNAME="$DOMAIN"
    HOSTWITHPROTOCOL="https://${DOMAIN}"
    SSLPROXY="true"
fi

cat > ${MOODLE_DIR}/config.php <<'EOFCONFIG'
<?php  // Moodle configuration file

unset($CFG);
global $CFG;
$CFG = new stdClass();

$CFG->dbtype    = 'pgsql';
$CFG->dblibrary = 'native';
$CFG->dbhost    = '127.0.0.1';
$CFG->dbname    = 'DBNAME_PLACEHOLDER';
$CFG->dbuser    = 'DBUSER_PLACEHOLDER';
$CFG->dbpass    = 'DBPASS_PLACEHOLDER';
$CFG->prefix    = 'mdl_';
$CFG->dboptions = array (
  'dbpersist' => 0,
  'dbport' => '5432',
  'dbsocket' => '',
);

// Hostname definition //
$hostname = 'HOSTNAME_PLACEHOLDER';
if ($hostname == '') {
  $hostwithprotocol = 'HOSTWITHPROTOCOL_PLACEHOLDER';
}
else {
  $hostwithprotocol = 'https://' . strtolower($hostname);
}

$CFG->wwwroot   = strtolower($hostwithprotocol);
$CFG->sslproxy = (substr($hostwithprotocol,0,5)=='https' ? true : false);

// Moodledata location - separated directories for better management //
$projroot = 'PROJROOT_PLACEHOLDER';
$CFG->dataroot = $projroot.'/data';
$CFG->tempdir = $projroot.'/temp';
$CFG->cachedir = $projroot.'/cache';
$CFG->localcachedir = $projroot.'/local';
$CFG->directorypermissions = 02770;

// X-Sendfile for Nginx - improves file serving performance //
$CFG->xsendfile = 'X-Accel-Redirect';
$CFG->xsendfilealiases = array(
    '/dataroot/' => $CFG->dataroot,
    '/cachedir/' => $CFG->cachedir,
    '/localcachedir/' => $CFG->localcachedir,
    '/tempdir/'  => $CFG->tempdir,
    '/filedir'   => $CFG->dataroot.'/filedir',
);

$CFG->admin = 'admin';

// Redis session handling (optional) //
$SessionEndpoint = 'REDIS_PLACEHOLDER';
if ($SessionEndpoint != '') {
  $CFG->session_handler_class = '\core\session\redis';
  $CFG->session_redis_host = $SessionEndpoint;
  $CFG->session_redis_port = 6379;
  $CFG->session_redis_acquire_lock_timeout = 120;
  $CFG->session_redis_lock_expire = 7200;
}

// Production settings - debugging disabled //
$CFG->debug = 0;
$CFG->debugdisplay = false;

require_once(__DIR__ . '/lib/setup.php');

// There is no php closing tag in this file,
// it is intentional because it prevents trailing whitespace problems!
EOFCONFIG

# Replace placeholders with actual values
sed -i "s|DBNAME_PLACEHOLDER|${DB_NAME}|g" ${MOODLE_DIR}/config.php
sed -i "s|DBUSER_PLACEHOLDER|${DB_USER}|g" ${MOODLE_DIR}/config.php
sed -i "s|DBPASS_PLACEHOLDER|${DB_PASS}|g" ${MOODLE_DIR}/config.php
sed -i "s|HOSTNAME_PLACEHOLDER|${HOSTNAME}|g" ${MOODLE_DIR}/config.php
sed -i "s|HOSTWITHPROTOCOL_PLACEHOLDER|${HOSTWITHPROTOCOL}|g" ${MOODLE_DIR}/config.php
sed -i "s|PROJROOT_PLACEHOLDER|${PROJ_ROOT}|g" ${MOODLE_DIR}/config.php
sed -i "s|REDIS_PLACEHOLDER|${REDIS_ENDPOINT}|g" ${MOODLE_DIR}/config.php

chown nginx:nginx ${MOODLE_DIR}/config.php
chmod 640 ${MOODLE_DIR}/config.php

echo "[11/12] Configuring Nginx with X-Sendfile support..."

if [ -z "$DOMAIN" ]; then
    SERVER_NAME="${SERVER_IP} _"
else
    SERVER_NAME="${DOMAIN}"
fi

cat > /etc/nginx/conf.d/moodle.conf <<EOF
server {
    listen 80 default_server;
    server_name ${SERVER_NAME};
    root ${MOODLE_DIR};
    index index.php index.html index.htm;

    client_max_body_size 200M;
    client_body_timeout 300s;

    # Main location
    location / {
        try_files \$uri \$uri/ =404;
    }

    # PHP processing
    location ~ [^/]\.php(/|$) {
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_index index.php;
        fastcgi_pass 127.0.0.1:9000;
        include fastcgi_params;
        fastcgi_param PATH_INFO \$fastcgi_path_info;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_read_timeout 300;
        fastcgi_buffers 16 16k;
        fastcgi_buffer_size 32k;
    }

    # X-Accel-Redirect for dataroot
    location /dataroot/ {
        internal;
        alias ${PROJ_ROOT}/data/;
    }

    # X-Accel-Redirect for cache
    location /cachedir/ {
        internal;
        alias ${PROJ_ROOT}/cache/;
    }

    # X-Accel-Redirect for local cache
    location /localcachedir/ {
        internal;
        alias ${PROJ_ROOT}/local/;
    }

    # X-Accel-Redirect for temp
    location /tempdir/ {
        internal;
        alias ${PROJ_ROOT}/temp/;
    }

    # X-Accel-Redirect for filedir
    location /filedir/ {
        internal;
        alias ${PROJ_ROOT}/data/filedir/;
    }

    # Deny access to hidden files
    location ~ /\\.ht {
        deny all;
    }

    # Deny access to sensitive files
    location ~ /(config\\.php|\\.git) {
        deny all;
    }
}
EOF

# Test Nginx configuration
nginx -t

echo "[12/12] Configuring SELinux and firewall..."

# Configure SELinux
setsebool -P httpd_can_network_connect 1
setsebool -P httpd_can_network_connect_db 1
semanage fcontext -a -t httpd_sys_rw_content_t "${MOODLE_DIR}(/.*)?"
semanage fcontext -a -t httpd_sys_rw_content_t "${PROJ_ROOT}(/.*)?"
restorecon -Rv ${MOODLE_DIR}
restorecon -Rv ${PROJ_ROOT}

# Configure firewall (if firewalld is installed)
if command -v firewall-cmd &> /dev/null; then
    firewall-cmd --permanent --add-service=http
    firewall-cmd --permanent --add-service=https
    firewall-cmd --reload
    echo "Firewall configured successfully"
else
    echo "Firewalld not installed - skipping firewall configuration"
    echo "Note: Ensure your cloud/VM provider allows HTTP (port 80) traffic"
fi

# Start Nginx
systemctl restart nginx

echo ""
echo "========================================"
echo "Production Installation Complete!"
echo "========================================"
echo ""
echo "SERVER INFORMATION:"
echo "-------------------"
echo "Server IP: ${SERVER_IP}"
if [ -n "$DOMAIN" ]; then
    echo "Domain: ${DOMAIN}"
    echo "Access URL: https://${DOMAIN}"
else
    echo "Access URL: http://${SERVER_IP}"
fi
echo ""
echo "DATABASE INFORMATION:"
echo "---------------------"
echo "Database Name: ${DB_NAME}"
echo "Database User: ${DB_USER}"
echo "Database Pass: ${DB_PASS}"
echo "Database Host: 127.0.0.1"
echo "Database Port: 5432"
echo ""
echo "DIRECTORY STRUCTURE:"
echo "--------------------"
echo "Moodle Code: ${MOODLE_DIR}"
echo "Data Root: ${PROJ_ROOT}/data"
echo "Temp Dir: ${PROJ_ROOT}/temp"
echo "Cache Dir: ${PROJ_ROOT}/cache"
echo "Local Cache: ${PROJ_ROOT}/local"
echo ""
echo "FEATURES ENABLED:"
echo "-----------------"
echo "✓ PHP 8.3 with OPcache"
echo "✓ PostgreSQL 15"
echo "✓ Nginx with X-Sendfile (X-Accel-Redirect)"
echo "✓ Separated data directories"
echo "✓ Production security settings"
echo "✓ Secure file permissions (02770)"
if [ "$INSTALL_REDIS" = "yes" ]; then
    echo "✓ Redis session handling"
else
    echo "✗ Redis (set INSTALL_REDIS='yes' to enable)"
fi
echo ""
echo "NEXT STEPS:"
echo "-----------"
echo "1. Visit your Moodle URL in a browser"
echo "2. Complete the web installation wizard"
echo "3. IMPORTANT: Change the database password!"
echo ""
if [ -z "$DOMAIN" ]; then
    echo "TO ADD A DOMAIN LATER:"
    echo "----------------------"
    echo "1. Update DOMAIN variable in this script"
    echo "2. Re-run the script, or manually update:"
    echo "   - ${MOODLE_DIR}/config.php (\$hostname variable)"
    echo "   - /etc/nginx/conf.d/moodle.conf (server_name)"
    echo "3. Set up SSL: dnf install certbot python3-certbot-nginx"
    echo "4. Run: certbot --nginx -d your-domain.com"
    echo ""
fi
echo "SECURITY RECOMMENDATIONS:"
echo "-------------------------"
echo "1. Change \$CFG->admin path in config.php"
echo "2. Set up SSL/TLS certificate"
echo "3. Configure automated backups"
echo "4. Set up monitoring and logging"
echo "5. Review and harden PostgreSQL settings"
echo ""
echo "========================================"