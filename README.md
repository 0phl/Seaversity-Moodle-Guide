# Seaversity Moodle Guide

A comprehensive guide and documentation for deploying, configuring, and maintaining Moodle 5 on Rocky Linux 9 with PostgreSQL, Nginx, and PHP-FPM.

### Fresh Installation 

This script automates the complete setup including PostgreSQL 15, PHP 8.3, Nginx with X-Sendfile optimization, and optional Redis session handling.

```bash
# Download the installation script directly
wget https://raw.githubusercontent.com/0phl/Seaversity-Moodle-Guide/main/Rocky%20Linux%20Moodle%205%20Installer%20Script/install_moodle.sh

# Make executable
chmod +x install_moodle.sh

# Edit configuration (change database password!)
nano install_moodle.sh

# Run the installation
sudo ./install_moodle.sh
```

### Upgrade Existing Installation

```bash
# Download the upgrade script directly
wget https://raw.githubusercontent.com/0phl/Seaversity-Moodle-Guide/main/Moodle%20Config/upgrade_moodle.sh

# Make executable
chmod +x upgrade_moodle.sh

# Run it
sudo ./upgrade_moodle.sh
```

---
