# Moodle 5.0 Production Installation Guide for Rocky Linux

A comprehensive step-by-step guide to manually install Moodle 5.0 on Rocky Linux with enterprise-grade configuration and performance optimizations.

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [System Update](#system-update)
3. [PostgreSQL 15 Installation](#postgresql-15-installation)
4. [PHP 8.3 Installation](#php-83-installation)
5. [Nginx Installation](#nginx-installation)
6. [Moodle 5.0 Download](#moodle-50-download)
7. [Directory Structure Setup](#directory-structure-setup)
8. [Redis Installation (Optional)](#redis-installation-optional)
9. [Moodle Configuration](#moodle-configuration)
10. [Nginx Configuration](#nginx-configuration)
11. [SELinux and Firewall](#selinux-and-firewall)
12. [Final Steps](#final-steps)

---

## Prerequisites

- Rocky Linux 9.x installed
- Root access to the server
- Basic knowledge of Linux command line
- (Optional) A domain name pointed to your server

**Important Configuration Variables:**
- Database Name: `moodle`
- Database User: `moodleuser`
- Database Password: `CHANGE_THIS_PASSWORD`
- Moodle Directory: `/data/content/lms/moodle`
- Moodle Data Directory: `/data/content/lms/moodledata`

---

## System Update

### Step 1: Update System Packages

```bash
sudo dnf update -y
sudo dnf install -y epel-release
```

**What this does:**
- Updates all system packages to latest versions
- Installs EPEL (Extra Packages for Enterprise Linux) repository for additional packages

---

## PostgreSQL 15 Installation

### Step 2: Install PostgreSQL 15

```bash
# Reset PostgreSQL module
sudo dnf module reset postgresql -y

# Enable PostgreSQL 15 stream
sudo dnf module enable postgresql:15 -y

# Install PostgreSQL server and contrib packages
sudo dnf install -y postgresql-server postgresql-contrib
```

### Step 3: Initialize PostgreSQL Database

```bash
# Initialize the database
sudo postgresql-setup --initdb

# Enable and start PostgreSQL service
sudo systemctl enable postgresql
sudo systemctl start postgresql

# Verify PostgreSQL is running
sudo systemctl status postgresql
```

### Step 4: Create Moodle Database and User

**Switch to PostgreSQL user and open psql:**

```bash
sudo -i -u postgres
psql
```

**Create the Moodle database with proper encoding:**

```sql
CREATE DATABASE moodle 
WITH ENCODING 'UTF8' 
LC_COLLATE='en_US.utf8' 
LC_CTYPE='en_US.utf8' 
TEMPLATE=template0;
```

**Create the database user:**

```sql
CREATE USER moodleuser WITH PASSWORD 'YOUR_SECURE_PASSWORD';
```

**Set the database owner:**

```sql
ALTER DATABASE moodle OWNER TO moodleuser;
```

**Important:** Replace `YOUR_SECURE_PASSWORD` with a strong password and save it securely.

**Verify the database and user were created:**

```sql
-- List all databases
\l

-- List all database roles
\du
```

You should see `moodle` in the database list and `moodleuser` in the roles list.

**Exit psql and return to your regular user:**

```sql
\q
exit
```

### Step 5: Configure PostgreSQL Authentication

```bash
# Edit pg_hba.conf to allow password authentication
sudo sed -i 's/ident/md5/g' /var/lib/pgsql/data/pg_hba.conf

# Restart PostgreSQL to apply changes
sudo systemctl restart postgresql
```

**What this does:**
- Changes authentication method from `ident` to `md5` (password-based)
- Allows Moodle to connect using username and password

---

## PHP 8.3 Installation

### Step 6: Install Remi Repository

```bash
# Install Remi repository
sudo dnf install -y https://rpms.remirepo.net/enterprise/remi-release-9.rpm

# Reset PHP module
sudo dnf module reset php -y

# Enable PHP 8.3 from Remi repository
sudo dnf module enable php:remi-8.3 -y
```

### Step 7: Install PHP and Required Extensions

```bash
sudo dnf install -y php php-fpm php-cli php-common php-pgsql php-gd php-xml \
    php-mbstring php-curl php-zip php-intl php-soap php-xmlrpc php-opcache \
    php-json php-sodium php-pecl-zip php-ldap
```

**These extensions are required for:**
- `php-pgsql`: PostgreSQL database connectivity
- `php-gd`: Image manipulation
- `php-xml`, `php-xmlrpc`: XML processing
- `php-mbstring`: Multi-byte string handling
- `php-curl`: External API communication
- `php-zip`: File compression/extraction
- `php-intl`: Internationalization
- `php-soap`: Web services
- `php-opcache`: Performance optimization
- `php-sodium`: Encryption
- `php-ldap`: LDAP authentication

### Step 8: Configure PHP for Production

```bash
# Edit main PHP configuration
sudo vi /etc/php.ini
```

**Find and modify these settings:**

```ini
cgi.fix_pathinfo=0
upload_max_filesize = 200M
post_max_size = 200M
max_execution_time = 300
memory_limit = 512M
max_input_vars = 5000
```

**Or use sed commands:**

```bash
sudo sed -i 's/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/' /etc/php.ini
sudo sed -i 's/upload_max_filesize = .*/upload_max_filesize = 200M/' /etc/php.ini
sudo sed -i 's/post_max_size = .*/post_max_size = 200M/' /etc/php.ini
sudo sed -i 's/max_execution_time = .*/max_execution_time = 300/' /etc/php.ini
sudo sed -i 's/memory_limit = .*/memory_limit = 512M/' /etc/php.ini
sudo sed -i 's/;max_input_vars = .*/max_input_vars = 5000/' /etc/php.ini
```

### Step 9: Configure OPcache for Production

```bash
# Create OPcache configuration
sudo tee -a /etc/php.d/10-opcache.ini > /dev/null <<EOF

; Production OPcache settings
opcache.enable=1
opcache.memory_consumption=256
opcache.interned_strings_buffer=16
opcache.max_accelerated_files=10000
opcache.revalidate_freq=60
opcache.fast_shutdown=1
EOF
```

**What OPcache does:**
- Caches compiled PHP code in memory
- Significantly improves performance
- Reduces CPU usage

### Step 10: Configure PHP-FPM

```bash
# Edit PHP-FPM pool configuration
sudo vi /etc/php-fpm.d/www.conf
```

**Find and modify these lines:**

```ini
user = nginx
group = nginx
listen = 127.0.0.1:9000
```

**Or use sed commands:**

```bash
sudo sed -i 's/user = apache/user = nginx/' /etc/php-fpm.d/www.conf
sudo sed -i 's/group = apache/group = nginx/' /etc/php-fpm.d/www.conf
sudo sed -i 's/listen = \/run\/php-fpm\/www.sock/listen = 127.0.0.1:9000/' /etc/php-fpm.d/www.conf
```

### Step 11: Enable and Start PHP-FPM

```bash
sudo systemctl enable php-fpm
sudo systemctl start php-fpm
sudo systemctl status php-fpm
```

---

## Nginx Installation

### Step 12: Add Official Nginx Repository

For modern features like HTTP/2 and better performance, we'll install the latest Nginx mainline version from the official Nginx repository instead of the older version in Rocky Linux's default repositories.

```bash
# Create Nginx repository file
sudo vi /etc/yum.repos.d/nginx.repo
```

**Paste the following content:**

```ini
[nginx-mainline]
name=nginx mainline repo
baseurl=http://nginx.org/packages/mainline/centos/9/$basearch/
gpgcheck=1
enabled=1
gpgkey=https://nginx.org/keys/nginx_signing.key
module_hotfixes=true
```

**Save and exit** (Press `Esc`, then type `:wq` and press `Enter`)

**Verify the file is correct:**

```bash
cat /etc/yum.repos.d/nginx.repo
```

Make sure the first line has the opening bracket: `[nginx-mainline]`

### Step 12a: Install Nginx

```bash
# Clean DNF cache
sudo dnf clean all

# Install Nginx from official repository
sudo dnf install -y nginx

# Verify the version (should be 1.27.x or higher)
nginx -v
```

**Expected output:**
```
nginx version: nginx/1.27.3 (or higher)
```

**Enable Nginx to start on boot:**

```bash
sudo systemctl enable nginx
```

**Note:** We'll configure and start Nginx later after setting up Moodle.

---

## Moodle 5.0 Download

### Step 13: Install Git

```bash
sudo dnf install -y git
```

### Step 14: Download Moodle 5.0

```bash
# Create directory structure
sudo mkdir -p /data/content/lms

# Navigate to the directory
cd /data/content/lms

# Clone Moodle 5.0 from GitHub
sudo git clone -b MOODLE_500_STABLE https://github.com/moodle/moodle.git moodle
```

**What this does:**
- Downloads Moodle 5.0 stable branch
- Places it in `/data/content/lms/moodle`

---

## Directory Structure Setup

### Step 15: Create Moodle Data Directories

Moodle requires separate directories for data storage outside the web root for security and performance.

```bash
# Create main data directory
sudo mkdir -p /data/content/lms/moodledata/data

# Create separated directories for different purposes
sudo mkdir -p /data/content/lms/moodledata/temp
sudo mkdir -p /data/content/lms/moodledata/cache
sudo mkdir -p /data/content/lms/moodledata/local
sudo mkdir -p /data/content/lms/moodledata/data/filedir
```

**Directory purposes:**
- `data`: Main data storage for user files
- `temp`: Temporary files
- `cache`: Cache files
- `local`: Local cache
- `filedir`: File storage

### Step 16: Set Permissions

```bash
# Set ownership to nginx user
sudo chown -R nginx:nginx /data/content/lms/moodledata
sudo chown -R nginx:nginx /data/content/lms/moodle

# Set proper permissions
sudo chmod -R 2770 /data/content/lms/moodledata
sudo chmod -R 755 /data/content/lms/moodle
```

**Permission explanation:**
- `2770`: Setgid bit + read/write/execute for owner and group
- `755`: Read/execute for everyone, write only for owner
- These permissions ensure security while allowing Moodle to function

---

## Redis Installation (Optional)

Redis can significantly improve Moodle's session handling and caching performance.

### Step 17: Install Redis

```bash
# Install Redis
sudo dnf install -y redis

# Enable and start Redis
sudo systemctl enable redis
sudo systemctl start redis

# Verify Redis is running
sudo systemctl status redis
```

**Benefits of Redis:**
- Faster session handling
- Reduced database load
- Better performance for concurrent users

**If you skip Redis:** Moodle will use file-based sessions, which works fine for smaller installations.

---

## Moodle Configuration

### Step 18: Create config.php

This is the main configuration file for Moodle.

```bash
# Create the configuration file
sudo vi /data/content/lms/moodle/config.php
```

**Paste the following configuration:**

```php
<?php  // Moodle configuration file

unset($CFG);
global $CFG;
$CFG = new stdClass();

$CFG->dbtype    = 'pgsql';
$CFG->dblibrary = 'native';
$CFG->dbhost    = '127.0.0.1';
$CFG->dbname    = 'moodle';
$CFG->dbuser    = 'moodleuser';
$CFG->dbpass    = 'YOUR_SECURE_PASSWORD';  // CHANGE THIS!
$CFG->prefix    = 'mdl_';
$CFG->dboptions = array (
  'dbpersist' => 0,
  'dbport' => '',
  'dbsocket' => '',
);

// Hostname definition //
$hostname = '';  // Leave empty for IP access, or set to 'moodle.yourdomain.com'
if ($hostname == '') {
  $hostwithprotocol = 'http://YOUR_SERVER_IP';  // CHANGE THIS!
}
else {
  $hostwithprotocol = 'https://' . strtolower($hostname);
}

$CFG->wwwroot   = strtolower($hostwithprotocol);
$CFG->sslproxy = (substr($hostwithprotocol,0,5)=='https' ? true : false);

// Uncomment if behind a reverse proxy (load balancer)
//$CFG->reverseproxy = true;

// Moodledata location //
$projroot = '/data/content/lms/moodledata/';
$CFG->dataroot = $projroot.'data';
$CFG->tempdir = $projroot.'temp';
$CFG->cachedir = $projroot.'cache';
$CFG->localcachedir = $projroot.'local';
$CFG->directorypermissions = 02770;

// Optional: Set default theme
//$CFG->theme = 'boost';

// X-Sendfile for Nginx - improves file serving performance //
$CFG->xsendfile = 'X-Accel-Redirect';

// X-Sendfile directory aliases for Nginx
$CFG->xsendfilealiases = array(
    '/dataroot/' => $CFG->dataroot,
    '/cachedir/' => $projroot.'cache',
    '/localcachedir/' => $projroot.'local',
    '/tempdir/'  => $projroot.'temp',
    '/filedir'   => $projroot.'data/filedir',
);

$CFG->admin = 'admin';

// Optional: Customize default blocks on new pages
//$CFG->defaultblocks_override = 'completion_progress,online_users,autoattend,html';

// Redis session handling (optional) //
$SessionEndpoint = '';
if ($SessionEndpoint != '') {
  $CFG->session_handler_class = '\core\session\redis';
  $CFG->session_redis_host = $SessionEndpoint;
  $CFG->session_redis_port = 6379;
  $CFG->session_redis_acquire_lock_timeout = 120;
  $CFG->session_redis_lock_expire = 7200;
}

require_once(__DIR__ . '/lib/setup.php');

// There is no php closing tag in this file,
// it is intentional because it prevents trailing whitespace problems!

//=========================================================================
// SETTINGS FOR DEVELOPMENT SERVERS - not intended for production use!!!
//=========================================================================
//
// Force a debugging mode regardless the settings in the site administration
// @error_reporting(E_ALL | E_STRICT);   // NOT FOR PRODUCTION SERVERS!
// @ini_set('display_errors', '1');      // NOT FOR PRODUCTION SERVERS!
// $CFG->debug = (E_ALL | E_STRICT);     // === DEBUG_DEVELOPER - NOT FOR PRODUCTION SERVERS!
// $CFG->debugdisplay = 1;               // NOT FOR PRODUCTION SERVERS!
//
// You can specify a comma separated list of user ids that always see
// debug messages, this overrides the debug flag in $CFG->debug and $CFG->debugdisplay
// for these users only.
// $CFG->debugusers = '1167';
```

**Important changes to make:**
1. Replace `YOUR_SECURE_PASSWORD` with your PostgreSQL password
2. Replace `YOUR_SERVER_IP` with your actual server IP address
3. If using a domain, set `$hostname = 'moodle.yourdomain.com'`
4. If behind a load balancer/reverse proxy, uncomment `$CFG->reverseproxy = true;`
5. If you installed Redis, set `$SessionEndpoint = '127.0.0.1';`

### Step 19: Get Your Server IP

```bash
hostname -I | awk '{print $1}'
```

Use this IP address in the `$hostwithprotocol` variable.

### Step 20: Set Config File Permissions

```bash
sudo chown nginx:nginx /data/content/lms/moodle/config.php
sudo chmod 640 /data/content/lms/moodle/config.php
```

---

## Nginx Configuration

### Step 21: Create Nginx Directory Structure

```bash
sudo mkdir -p /etc/nginx/sites-available
sudo mkdir -p /etc/nginx/sites-enabled
```

### Step 22: Create Moodle Nginx Configuration

```bash
sudo vi /etc/nginx/sites-available/lms.conf
```

**Paste the following configuration:**

```nginx
server {
    # SSL configuration (commented out - enable after SSL setup)
    #listen                  443 ssl reuseport;
    #listen                  [::]:443 ssl reuseport;
    #listen                  443 quic reuseport;
    #listen                  [::]:443 quic reuseport;

    # HTTP configuration
    listen                  80 reuseport;
    listen                  [::]:80 reuseport;
    server_name             YOUR_DOMAIN_OR_IP;  # CHANGE THIS!
    set                     $base /data/content/lms;
    http2 on;

    client_header_timeout 60s;

    # Advertise that QUIC is available on the configured port (for HTTP/3)
    add_header Alt-Svc 'h3=":$server_port"; ma=86400';

    # Main Moodle location
    location / {
         # Security configuration
         include                 nginxconfig.io/security-moodle.conf;

         root    $base/moodle;
         index index.php;
         try_files $uri $uri/ /index.php?$query_string;

         # Additional configuration
         include nginxconfig.io/general-moodle.conf;
    }

    # PHP processing
    location ~ ^(.+\.php)(.*)$ {
         root                            $base/moodle;
         fastcgi_split_path_info         ^(.+\.php)(.*)$;
         include                         nginxconfig.io/php_fastcgi-moodle.conf;
         fastcgi_pass                    127.0.0.1:9000;  # Use TCP socket
         include                         mime.types;
         fastcgi_param   PATH_INFO       $fastcgi_path_info;
         fastcgi_param   PHP_VALUE       "upload_max_filesize=3072M \n post_max_size=3072M \n max_input_vars=5000 \n max_execution_time=600;";
         client_max_body_size            3072M;
         client_body_buffer_size         3072M;
         client_body_timeout 600s;
         fastcgi_read_timeout 600;

         # Logging
         error_log               /var/log/nginx/lms.error.log warn;
    }

    # X-Accel-Redirect locations for improved file serving performance
    location /dataroot/ {
        internal;
        alias $base/moodledata/data/;
    }

    location /cachedir/ {
        internal;
        alias $base/moodledata/cache/;
    }

    location /localcachedir/ {
        internal;
        alias $base/moodledata/local/;
    }

    location /tempdir/ {
        internal;
        alias $base/moodledata/temp/;
    }

    location /filedir/ {
        internal;
        alias $base/moodledata/filedir/;
    }
}

# HTTP to HTTPS redirect (commented out - enable after SSL setup)
#server {
#    listen 80;
#    listen [::]:80;
#    server_name YOUR_DOMAIN_OR_IP;
#    
#    location / {
#        return 301 https://$host$request_uri;
#    }
#}
```

**Important changes to make:**
1. Replace `YOUR_DOMAIN_OR_IP` with your actual domain or server IP address
2. After this basic setup, we'll create the security and general configuration files

### Step 22a: Create Security Configuration for Moodle

```bash
sudo mkdir -p /etc/nginx/nginxconfig.io
sudo vi /etc/nginx/nginxconfig.io/security-moodle.conf
```

**Paste the following:**

```nginx
# Security headers
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;

# Deny access to hidden files
location ~ /\. {
    deny all;
}

# Deny access to sensitive Moodle files
location ~ /(config\.php|\.git|\.gitignore|readme\.txt|CHANGELOG\.txt) {
    deny all;
}

# Deny access to version control files
location ~ /\.(git|svn|hg) {
    deny all;
}
```

### Step 22b: Create General Configuration for Moodle

```bash
sudo vi /etc/nginx/nginxconfig.io/general-moodle.conf
```

**Paste the following:**

```nginx
# Gzip compression
gzip on;
gzip_vary on;
gzip_proxied any;
gzip_comp_level 6;
gzip_types text/plain text/css text/xml text/javascript application/json application/javascript application/xml+rss application/rss+xml font/truetype font/opentype application/vnd.ms-fontobject image/svg+xml;

# Browser caching for static assets
location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2|ttf|eot)$ {
    expires 30d;
    add_header Cache-Control "public, immutable";
}
```

### Step 22c: Create PHP FastCGI Configuration for Moodle

```bash
sudo vi /etc/nginx/nginxconfig.io/php_fastcgi-moodle.conf
```

**Paste the following:**

```nginx
# FastCGI parameters
fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
fastcgi_param QUERY_STRING $query_string;
fastcgi_param REQUEST_METHOD $request_method;
fastcgi_param CONTENT_TYPE $content_type;
fastcgi_param CONTENT_LENGTH $content_length;

fastcgi_param SCRIPT_NAME $fastcgi_script_name;
fastcgi_param REQUEST_URI $request_uri;
fastcgi_param DOCUMENT_URI $document_uri;
fastcgi_param DOCUMENT_ROOT $document_root;
fastcgi_param SERVER_PROTOCOL $server_protocol;
fastcgi_param REQUEST_SCHEME $scheme;
fastcgi_param HTTPS $https if_not_empty;

fastcgi_param GATEWAY_INTERFACE CGI/1.1;
fastcgi_param SERVER_SOFTWARE nginx/$nginx_version;

fastcgi_param REMOTE_ADDR $remote_addr;
fastcgi_param REMOTE_PORT $remote_port;
fastcgi_param SERVER_ADDR $server_addr;
fastcgi_param SERVER_PORT $server_port;
fastcgi_param SERVER_NAME $server_name;

# PHP only, required if PHP was built with --enable-force-cgi-redirect
fastcgi_param REDIRECT_STATUS 200;

# FastCGI buffers
fastcgi_buffers 16 16k;
fastcgi_buffer_size 32k;
fastcgi_intercept_errors on;
```

### Step 23: Enable the Site Configuration

```bash
# Create symbolic link
sudo ln -sf /etc/nginx/sites-available/lms.conf /etc/nginx/sites-enabled/lms.conf
```

### Step 24: Update Main Nginx Configuration

```bash
# Edit nginx.conf
sudo vi /etc/nginx/nginx.conf
```

**Find the line:**
```nginx
include /etc/nginx/conf.d/*.conf;
```

**Add this line right after it:**
```nginx
include /etc/nginx/sites-enabled/*.conf;
```

### Step 25: Test Nginx Configuration

```bash
sudo nginx -t
```

**Expected output:**
```
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
```

---

## SELinux and Firewall

### Step 26: Configure SELinux

```bash
# Allow Nginx to connect to network and database
sudo setsebool -P httpd_can_network_connect 1
sudo setsebool -P httpd_can_network_connect_db 1

# Set SELinux contexts for Moodle directories
sudo semanage fcontext -a -t httpd_sys_rw_content_t "/data/content/lms/moodle(/.*)?"
sudo semanage fcontext -a -t httpd_sys_rw_content_t "/data/content/lms/moodledata(/.*)?"

# Apply the contexts
sudo restorecon -Rv /data/content/lms/moodle
sudo restorecon -Rv /data/content/lms/moodledata
```

**What this does:**
- Allows Nginx to function properly with SELinux enabled
- Maintains system security while allowing required operations

### Step 27: Configure Firewall

```bash
# Add HTTP and HTTPS services
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https

# Reload firewall
sudo firewall-cmd --reload

# Verify rules
sudo firewall-cmd --list-all
```

**If firewalld is not installed:**
```bash
sudo dnf install -y firewalld
sudo systemctl enable firewalld
sudo systemctl start firewalld
# Then run the firewall commands above
```

---

## Final Steps

### Step 28: Start Nginx

```bash
sudo systemctl restart nginx
sudo systemctl status nginx
```

### Step 29: Verify All Services Are Running

```bash
# Check PostgreSQL
sudo systemctl status postgresql

# Check PHP-FPM
sudo systemctl status php-fpm

# Check Nginx
sudo systemctl status nginx

# Check Redis (if installed)
sudo systemctl status redis
```

### Step 30: Access Moodle Web Installer

1. Open your web browser
2. Navigate to: `http://YOUR_SERVER_IP` (or your domain)
3. Follow the Moodle installation wizard
4. Select language and click "Next"
5. Confirm paths (should be pre-filled from config.php)
6. Choose PostgreSQL as database driver
7. Database settings should be pre-filled
8. Accept license agreement
9. Wait for environment checks to complete
10. Install required components
11. Create administrator account

**Environment Check Issues:**
If you encounter any warnings:
- Red errors must be fixed
- Orange warnings are optional but recommended
- Green checks indicate everything is okay

### Step 31: Post-Installation Security

After completing the web installation:

1. **Change admin URL** (optional but recommended):
```bash
sudo vi /data/content/lms/moodle/config.php
```
Change `$CFG->admin = 'admin';` to something unique like `$CFG->admin = 'siteadmin123';`

2. **Set up SSL Certificate** (if using domain):
```bash
sudo dnf install -y certbot python3-certbot-nginx
sudo certbot --nginx -d yourdomain.com
```

3. **Set up automated backups**:
```bash
# Create backup script directory
sudo mkdir -p /root/scripts

# Create backup script
sudo vi /root/scripts/moodle-backup.sh
```

**Basic backup script:**
```bash
#!/bin/bash
BACKUP_DIR="/backup/moodle"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

# Backup database
sudo -u postgres pg_dump moodledb | gzip > $BACKUP_DIR/moodle_db_$DATE.sql.gz

# Backup moodledata
tar -czf $BACKUP_DIR/moodledata_$DATE.tar.gz /data/content/lms/moodledata

# Keep only last 7 days of backups
find $BACKUP_DIR -name "*.gz" -mtime +7 -delete
```

Make it executable:
```bash
sudo chmod +x /root/scripts/moodle-backup.sh
```

4. **Set up Cron** for Moodle maintenance tasks:
```bash
sudo crontab -u nginx -e
```

Add this line:
```
*/5 * * * * /usr/bin/php /data/content/lms/moodle/admin/cli/cron.php > /dev/null
```

---

## Installation Summary

**What You've Installed:**
- ✓ Rocky Linux 9 with latest updates
- ✓ PostgreSQL 15 database server
- ✓ PHP 8.3 with all required extensions
- ✓ PHP-FPM for improved performance
- ✓ OPcache for PHP code caching
- ✓ Nginx web server with X-Sendfile support
- ✓ Moodle 5.0 from official GitHub repository
- ✓ Redis for session handling (optional)
- ✓ Separated data directories for better organization
- ✓ Production-grade security settings
- ✓ SELinux properly configured
- ✓ Firewall configured for web access

**Directory Structure:**
```
/data/content/lms/
├── moodle/                 # Moodle application code
│   ├── config.php         # Configuration file
│   └── ...                # Moodle files
└── moodledata/            # Moodle data (outside web root)
    ├── data/              # Main data storage
    ├── temp/              # Temporary files
    ├── cache/             # Cache files
    └── local/             # Local cache
```

**Service Ports:**
- Nginx: 80 (HTTP), 443 (HTTPS when SSL configured)
- PostgreSQL: 5432
- PHP-FPM: 9000
- Redis: 6379 (if installed)

---

## Troubleshooting

### Common Issues

**1. Permission Denied Errors**
```bash
sudo chown -R nginx:nginx /data/content/lms/moodledata
sudo chmod -R 2770 /data/content/lms/moodledata
sudo restorecon -Rv /data/content/lms/moodledata
```

**2. Can't Connect to Database**
```bash
# Check PostgreSQL is running
sudo systemctl status postgresql

# Test database connection
psql -h 127.0.0.1 -U moodleuser -d moodle
```

**3. PHP Errors**
```bash
# Check PHP-FPM logs
sudo tail -f /var/log/php-fpm/www-error.log

# Check Nginx error logs
sudo tail -f /var/log/nginx/error.log
```

**4. SELinux Blocking Operations**
```bash
# Check SELinux denials
sudo ausearch -m avc -ts recent

# Temporarily set to permissive mode for testing
sudo setenforce 0

# Re-enable after fixing
sudo setenforce 1
```

**5. Firewall Blocking Access**
```bash
# Check if firewall is blocking
sudo firewall-cmd --list-all

# Temporarily stop firewall for testing
sudo systemctl stop firewalld
```

---

## Performance Optimization Tips

1. **Enable Moodle Caching:**
   - Site administration → Plugins → Caching → Configuration
   - Enable all cache stores

2. **Configure Database Connection Pooling:**
   - Edit `/var/lib/pgsql/data/postgresql.conf`
   - Increase `max_connections` if needed

3. **Optimize PHP-FPM Pool:**
   - Edit `/etc/php-fpm.d/www.conf`
   - Adjust `pm.max_children`, `pm.start_servers`, etc.

4. **Enable Gzip Compression in Nginx:**
   - Edit `/etc/nginx/nginx.conf`
   - Enable and configure gzip settings

5. **Monitor Resources:**
```bash
# Monitor system resources
htop

# Monitor Nginx
sudo tail -f /var/log/nginx/access.log

# Monitor PostgreSQL
sudo -u postgres psql -c "SELECT * FROM pg_stat_activity;"
```

---

## Security Checklist

- [ ] Changed default database password
- [ ] Changed `$CFG->admin` path in config.php
- [ ] Set up SSL/TLS certificate
- [ ] Configured automated backups
- [ ] Set up Moodle cron job
- [ ] Reviewed PostgreSQL pg_hba.conf settings
- [ ] Enabled firewall with only necessary ports
- [ ] Kept SELinux enabled
- [ ] Set up monitoring and logging
- [ ] Documented all passwords securely
- [ ] Tested disaster recovery procedures

---

## Additional Resources

- **Official Moodle Documentation:** https://docs.moodle.org
- **Moodle Installation Guide:** https://docs.moodle.org/en/Installation
- **Moodle Security:** https://docs.moodle.org/en/Security
- **PostgreSQL Documentation:** https://www.postgresql.org/docs/
- **Nginx Documentation:** https://nginx.org/en/docs/
- **PHP Documentation:** https://www.php.net/docs.php

---

## Support

If you encounter issues:
1. Check Moodle logs: `/data/content/lms/moodledata/data/`
2. Check system logs: `/var/log/nginx/` and `/var/log/php-fpm/`
3. Visit Moodle forums: https://moodle.org/forums/
4. Consult official documentation

---

**Installation completed!** Your Moodle 5.0 instance is now ready for production use.