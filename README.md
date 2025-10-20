# Moodle 5.0 Production Installation Script for Rocky Linux

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Rocky Linux](https://img.shields.io/badge/Rocky%20Linux-9-green.svg)](https://rockylinux.org/)
[![Moodle](https://img.shields.io/badge/Moodle-5.0-orange.svg)](https://moodle.org/)

A comprehensive, production-ready installation script for Moodle 5.0 on Rocky Linux 9. This script automates the complete setup including PostgreSQL 15, PHP 8.3, Nginx with X-Sendfile optimization, and optional Redis session handling.

## Features

- ✅ **Fully Automated Installation** - One script installs everything
- ✅ **Production-Grade Configuration** - Enterprise-level setup out of the box
- ✅ **Performance Optimized** - Nginx X-Sendfile, OPcache, separated cache directories
- ✅ **Security Hardened** - SELinux configured, secure file permissions, firewall rules
- ✅ **Flexible Deployment** - Works with IP address or domain name
- ✅ **Redis Support** - Optional Redis for session handling (load balancing ready)
- ✅ **PostgreSQL 15** - Latest stable database with optimized settings
- ✅ **PHP 8.3** - Latest PHP version compatible with Moodle 5.0

## What Gets Installed

| Component | Version | Purpose |
|-----------|---------|---------|
| **Rocky Linux** | 9 | Operating System |
| **PostgreSQL** | 15 | Database Server |
| **PHP** | 8.3 | Application Runtime |
| **Nginx** | Latest | Web Server |
| **Moodle** | 5.0 | Learning Management System |
| **Redis** | Latest (Optional) | Session Handler |

## Directory Structure

The script creates an enterprise-grade directory structure:

```
/var/www/moodle/          # Moodle application code
/var/moodledata/
  ├── data/               # Main data storage
  ├── temp/               # Temporary files
  ├── cache/              # Cache files
  ├── local/              # Local cache
  └── data/filedir/       # User uploaded files
```

## Quick Start

### Prerequisites

- Rocky Linux 9 (fresh installation recommended)
- Root access
- At least 2GB RAM
- 20GB+ disk space
- Internet connection

### Basic Installation (IP-based)

```bash
# Download the script
wget https://raw.githubusercontent.com/0phl/moodle5-rocky-installer/main/install_moodle.sh

# Make it executable
chmod +x install_moodle.sh

# Edit configuration (change database password!)
nano install_moodle.sh

# Run the installation
sudo ./install_moodle.sh
```

### Installation with Domain

```bash
# Edit the script and set:
DOMAIN="moodle.yourdomain.com"
DB_PASS="YourSecurePassword123!"

# Run installation
sudo ./install_moodle.sh
```

##  Configuration Options

Edit these variables at the top of `install_moodle.sh`:

```bash
# Database Configuration
DB_NAME="moodledb"                    # Database name
DB_USER="moodleuser"                  # Database user
DB_PASS="Moodle@Pass123!"            # CHANGE THIS!

# Domain/URL Configuration
DOMAIN=""                             # Leave empty for IP, or set your domain

# Optional Features
INSTALL_REDIS="no"                    # Set to "yes" for Redis sessions

# Directory Configuration
MOODLE_DIR="/var/www/moodle"         # Moodle code location
PROJ_ROOT="/var/moodledata"          # Data directory location
```

##  Complete Installation Guide

### Step 1: Prepare Your Server

```bash
# Update your system
sudo dnf update -y

# Create a directory for the script
mkdir -p ~/moodle-install
cd ~/moodle-install
```

### Step 2: Download the Script

```bash
# Option 1: Using wget
wget https://raw.githubusercontent.com/0phl/moodle5-rocky-installer/main/install_moodle.sh

# Option 2: Using curl
curl -O https://raw.githubusercontent.com/0phl/moodle5-rocky-installer/main/install_moodle.sh

# Option 3: Clone the repository
git clone https://github.com/0phl/moodle5-rocky-installer.git
cd moodle5-rocky-installer
```

### Step 3: Configure the Script

```bash
# Open the script in an editor
nano install_moodle.sh

# Mandatory changes:
# 1. Change DB_PASS to a strong password
# 2. (Optional) Set DOMAIN if you have one
# 3. (Optional) Set INSTALL_REDIS="yes" if needed
```

### Step 4: Run the Installation

```bash
# Make the script executable
chmod +x install_moodle.sh

# Run as root
sudo ./install_moodle.sh
```

The installation takes approximately **5-10 minutes** depending on your internet connection.

### Step 5: Complete Web Installation

1. Open your browser and navigate to:
   - With domain: `https://yourdomain.com`
   - Without domain: `http://YOUR_SERVER_IP`

2. Follow the Moodle installation wizard:
   - **Language**: Choose your language
   - **Paths**: Pre-configured (just click Next)
   - **Database**: Pre-configured (just click Next)
   - **License**: Accept the GPL license
   - **Server Checks**: Should all pass 
   - **Admin Account**: Create your admin user
   - **Site Settings**: Configure your site name

3. Installation complete! 

##  Security Recommendations

After installation, implement these security measures:

### 1. Change Admin Panel Path

```bash
# Edit config.php
nano /var/www/moodle/config.php

# Change this line:
$CFG->admin = 'secretadmin2025';  # Instead of 'admin'
```

### 2. Set Up SSL/TLS Certificate

```bash
# Install Certbot
dnf install -y certbot python3-certbot-nginx

# Get SSL certificate
certbot --nginx -d yourdomain.com

# Auto-renewal is configured automatically
```

### 3. Change Database Password

```bash
# Update PostgreSQL password
sudo -u postgres psql
ALTER USER moodleuser WITH PASSWORD 'NewStrongPassword123!';
\q

# Update config.php
nano /var/www/moodle/config.php
# Change $CFG->dbpass = 'NewStrongPassword123!';
```

### 4. Configure Firewall (if not automatically configured)

```bash
firewall-cmd --permanent --add-service=http
firewall-cmd --permanent --add-service=https
firewall-cmd --reload
```

##  Performance Optimization

This script includes several performance optimizations:

### X-Sendfile (X-Accel-Redirect)

Nginx serves files directly instead of through PHP:

```nginx
# Automatically configured in /etc/nginx/conf.d/moodle.conf
location /dataroot/ {
    internal;
    alias /var/moodledata/data/;
}
```

**Benefits:**
-  Faster file downloads (videos, PDFs, etc.)
-  Reduced PHP memory usage
-  Better concurrent user handling

### PHP OPcache

Pre-configured for production:

```ini
opcache.enable=1
opcache.memory_consumption=256
opcache.max_accelerated_files=10000
opcache.revalidate_freq=60
```

### Separated Cache Directories

Different types of data in separate directories for easier management:
- Better cache invalidation
- Easier backup strategies
- Improved I/O performance

##  Redis Session Handling (Optional)

For load-balanced or high-traffic deployments:

```bash
# Set in script before running
INSTALL_REDIS="yes"
```

**Benefits:**
- Faster session handling
- Support for multiple web servers
- Better scalability

**Configuration is automatic** - no manual setup required!

##  Backup and Restore

### Automated Backup Script

Create `/root/backup_moodle.sh`:

```bash
#!/bin/bash
BACKUP_DIR="/backup/moodle"
DATE=$(date +%Y%m%d_%H%M%S)

# Create backup directory
mkdir -p $BACKUP_DIR

# Backup database
sudo -u postgres pg_dump moodledb | gzip > $BACKUP_DIR/moodledb_$DATE.sql.gz

# Backup moodledata
tar -czf $BACKUP_DIR/moodledata_$DATE.tar.gz /var/moodledata

# Backup moodle code (optional)
tar -czf $BACKUP_DIR/moodle_$DATE.tar.gz /var/www/moodle

# Keep only last 7 days
find $BACKUP_DIR -name "*.gz" -mtime +7 -delete

echo "Backup completed: $DATE"
```

### Schedule Daily Backups

```bash
# Make script executable
chmod +x /root/backup_moodle.sh

# Add to crontab (runs daily at 2 AM)
crontab -e

# Add this line:
0 2 * * * /root/backup_moodle.sh >> /var/log/moodle_backup.log 2>&1
```

### Restore from Backup

```bash
# Restore database
gunzip < moodledb_YYYYMMDD_HHMMSS.sql.gz | sudo -u postgres psql moodledb

# Restore moodledata
tar -xzf moodledata_YYYYMMDD_HHMMSS.tar.gz -C /

# Restore moodle code
tar -xzf moodle_YYYYMMDD_HHMMSS.tar.gz -C /

# Fix permissions
chown -R nginx:nginx /var/www/moodle /var/moodledata
```

##  Troubleshooting

### Installation Issues

**Issue: Firewall command not found**
```bash
# Solution: Already handled in script
# Firewall configuration is optional
```

**Issue: max_input_vars error**
```bash
# Solution: Already fixed in script
# Manual fix if needed:
sed -i 's/;max_input_vars = .*/max_input_vars = 5000/' /etc/php.ini
systemctl restart php-fpm
```

**Issue: SELinux blocking Moodle**
```bash
# Check SELinux denials
ausearch -m avc -ts recent

# Restore contexts
restorecon -Rv /var/www/moodle /var/moodledata
```

### Runtime Issues

**Issue: 502 Bad Gateway**
```bash
# Check PHP-FPM status
systemctl status php-fpm

# Check logs
tail -f /var/log/php-fpm/error.log

# Restart services
systemctl restart php-fpm nginx
```

**Issue: Database connection error**
```bash
# Check PostgreSQL status
systemctl status postgresql-15

# Test connection
psql -h 127.0.0.1 -U moodleuser -d moodledb

# Check pg_hba.conf
cat /var/lib/pgsql/15/data/pg_hba.conf
```

**Issue: Permission denied errors**
```bash
# Fix permissions
chown -R nginx:nginx /var/www/moodle /var/moodledata
chmod -R 755 /var/www/moodle
chmod -R 2770 /var/moodledata

# Restore SELinux contexts
restorecon -Rv /var/www/moodle /var/moodledata
```

##  Updating Moodle

```bash
# Backup first!
/root/backup_moodle.sh

# Put site in maintenance mode
sudo -u nginx php /var/www/moodle/admin/cli/maintenance.php --enable

# Pull latest code
cd /var/www/moodle
git fetch
git checkout MOODLE_50_STABLE  # or desired version
git pull

# Run upgrade
sudo -u nginx php /var/www/moodle/admin/cli/upgrade.php --non-interactive

# Clear cache
sudo -u nginx php /var/www/moodle/admin/cli/purge_caches.php

# Disable maintenance mode
sudo -u nginx php /var/www/moodle/admin/cli/maintenance.php --disable
```

##  System Requirements

### Minimum Requirements
- **CPU**: 2 cores
- **RAM**: 2GB
- **Disk**: 20GB
- **OS**: Rocky Linux 9

### Recommended for Production
- **CPU**: 4+ cores
- **RAM**: 8GB+
- **Disk**: 100GB+ (SSD recommended)
- **Network**: 100Mbps+