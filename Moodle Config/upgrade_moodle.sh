#!/bin/bash

# Complete Moodle 4.2 to 5.0 Upgrade Script - FIXED VERSION
# System: Rocky Linux 9.6
# Handles: Auto-detect web user, BusyBox wget, empty database
# Author: Fixed based on real-world testing

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

BASE_PATH="/data/content/lms"
MOODLE_PATH="${BASE_PATH}/moodle"
MOODLEDATA_PATH="${BASE_PATH}/moodledata"
PHP_BIN="php83"
MOODLE_VERSION="5.0.3+"
MOODLE_DOWNLOAD_URL="https://download.moodle.org/download.php/direct/stable500/moodle-latest-500.tgz"

DB_HOST="127.0.0.1"
DB_NAME="moodle"
DB_USER="moodleuser"
DB_PASS="Seaversity@2025"

echo -e "${BLUE}========================================================${NC}"
echo -e "${BLUE}  Moodle 5.0.3+ Upgrade Script - Fixed Version${NC}"
echo -e "${BLUE}  Auto-detects web user and handles edge cases${NC}"
echo -e "${BLUE}========================================================${NC}"
echo ""

print_status() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_section() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

if [ "$EUID" -ne 0 ]; then 
    print_error "Please run as root"
    exit 1
fi

# ============================================
# DETECT WEB SERVER USER
# ============================================
print_section "Detecting Web Server Configuration"

# Detect which user PHP-FPM is actually running as
WEB_USER="apache"  # default
if ps aux | grep -E "php-fpm.*master" | grep -v grep | grep -q apache; then
    WEB_USER="apache"
    print_status "✓ Detected PHP-FPM running as: apache"
elif ps aux | grep -E "php-fpm.*master" | grep -v grep | grep -q nginx; then
    WEB_USER="nginx"
    print_status "✓ Detected PHP-FPM running as: nginx"
elif ps aux | grep -E "php-fpm.*master" | grep -v grep | grep -q www-data; then
    WEB_USER="www-data"
    print_status "✓ Detected PHP-FPM running as: www-data"
else
    print_warning "Could not detect PHP-FPM user, using default: apache"
fi

# Verify the user exists
if ! id "$WEB_USER" &>/dev/null; then
    print_error "User $WEB_USER does not exist!"
    exit 1
fi

print_status "Web server will run as: $WEB_USER"

# ============================================
# CHECK DISK SPACE
# ============================================
print_section "Checking Disk Space"

AVAILABLE_GB=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
print_status "Available space: ${AVAILABLE_GB}GB"

if [ "$AVAILABLE_GB" -lt 3 ]; then
    print_error "Insufficient disk space! Need at least 3GB free."
    print_error "Current available: ${AVAILABLE_GB}GB"
    echo ""
    echo "Run these commands to free up space:"
    echo "  rm -rf /data/content/lms/moodledata/temp/*"
    echo "  rm -rf /data/content/lms/moodledata/cache/*"
    echo "  rm -rf /data/content/lms/moodledata/sessions/*"
    echo "  dnf clean all"
    exit 1
fi

# ============================================
# INSTALL PHP EXTENSIONS
# ============================================
print_section "STEP 1: Installing Required PHP Extensions"

REQUIRED_PACKAGES=(
    "php83-php-pgsql"
    "php83-php-gd"
    "php83-php-intl"
    "php83-php-mbstring"
    "php83-php-xml"
    "php83-php-zip"
    "php83-php-soap"
    "php83-php-sodium"
)

for package in "${REQUIRED_PACKAGES[@]}"; do
    if ! rpm -q "$package" &> /dev/null; then
        print_status "Installing $package..."
        dnf install -y "$package" || print_warning "Failed to install $package"
    else
        print_status "✓ $package already installed"
    fi
done

# Restart services with detected user
print_status "Restarting web services..."
if systemctl is-active --quiet nginx; then
    systemctl restart nginx
    print_status "✓ Nginx restarted"
fi

# Restart both PHP-FPM versions if they exist
for php_version in php82-php-fpm php83-php-fpm; do
    if systemctl is-active --quiet $php_version; then
        systemctl restart $php_version
        print_status "✓ $php_version restarted"
    fi
done

# ============================================
# VERIFY REQUIREMENTS
# ============================================
print_section "STEP 2: Verifying System Requirements"

PHP_VERSION=$($PHP_BIN -r 'echo PHP_VERSION;')
print_status "PHP version: $PHP_VERSION"

PG_VERSION=$(psql -V | grep -oP '\d+\.\d+' | head -1)
print_status "PostgreSQL version: $PG_VERSION"

print_status "Verifying PHP extensions..."
REQUIRED_EXTENSIONS=("pgsql" "gd" "intl" "mbstring" "xml" "zip" "soap" "sodium")
MISSING_EXTENSIONS=()

for ext in "${REQUIRED_EXTENSIONS[@]}"; do
    if ! $PHP_BIN -m | grep -qi "^$ext$"; then
        MISSING_EXTENSIONS+=("$ext")
    fi
done

if [ ${#MISSING_EXTENSIONS[@]} -gt 0 ]; then
    print_error "Missing required PHP extensions: ${MISSING_EXTENSIONS[*]}"
    exit 1
fi
print_status "✓ All required PHP extensions verified"

# ============================================
# BACKUP CONFIG
# ============================================
print_section "STEP 3: Backing Up Configuration"

if [ -f "${MOODLE_PATH}/config.php" ]; then
    cp "${MOODLE_PATH}/config.php" "/root/config.php.backup.$(date +%Y%m%d_%H%M%S)"
    print_status "✓ Config backed up to /root/"
fi

# ============================================
# CLEANUP
# ============================================
print_section "STEP 4: Cleaning Up Old Files"

print_status "Removing old downloads..."
rm -f "${BASE_PATH}/moodle-latest-500.tgz"
rm -f "${BASE_PATH}/moodle-5.0.tgz"
rm -rf /tmp/moodle

if [ -d "${MOODLE_PATH}.old" ]; then
    print_status "Removing old .old directory..."
    rm -rf "${MOODLE_PATH}.old"
fi

# ============================================
# DOWNLOAD MOODLE
# ============================================
print_section "STEP 5: Downloading Moodle 5.0.3+"

cd "$BASE_PATH"
print_status "Downloading latest stable weekly build..."
print_warning "This may take a few minutes (downloading ~71MB)..."

# Handle both GNU wget and BusyBox wget
if wget --help 2>&1 | grep -q 'show-progress'; then
    wget -q --show-progress -O moodle-latest-500.tgz "$MOODLE_DOWNLOAD_URL"
else
    # BusyBox wget or older wget
    wget -O moodle-latest-500.tgz "$MOODLE_DOWNLOAD_URL"
fi

if [ ! -f "moodle-latest-500.tgz" ]; then
    print_error "Download failed!"
    exit 1
fi

DOWNLOAD_SIZE=$(du -h moodle-latest-500.tgz | cut -f1)
print_status "✓ Downloaded Moodle 5.0.3+ ($DOWNLOAD_SIZE)"

# ============================================
# EXTRACT
# ============================================
print_section "STEP 6: Extracting Moodle 5.0.3+"

print_status "Extracting to /tmp..."
tar -xzf moodle-latest-500.tgz -C /tmp/
print_status "✓ Extracted successfully"

# ============================================
# INSTALL NEW CODE
# ============================================
print_section "STEP 7: Installing New Moodle Code"

if [ -d "$MOODLE_PATH" ]; then
    print_status "Moving old installation to ${MOODLE_PATH}.old..."
    mv "${MOODLE_PATH}" "${MOODLE_PATH}.old"
fi

print_status "Installing new Moodle 5.0.3+..."
mv /tmp/moodle "$MOODLE_PATH"
print_status "✓ New code installed"

# ============================================
# RESTORE CONFIG
# ============================================
print_section "STEP 8: Restoring Configuration"

LATEST_BACKUP=$(ls -t /root/config.php.backup.* 2>/dev/null | head -1)
if [ -f "$LATEST_BACKUP" ]; then
    cp "$LATEST_BACKUP" "${MOODLE_PATH}/config.php"
    print_status "✓ Configuration restored from $LATEST_BACKUP"
elif [ -f "${MOODLE_PATH}.old/config.php" ]; then
    cp "${MOODLE_PATH}.old/config.php" "${MOODLE_PATH}/config.php"
    print_status "✓ Configuration restored from old installation"
fi

# ============================================
# SET PERMISSIONS (USING DETECTED USER!)
# ============================================
print_section "STEP 9: Setting Permissions"

print_status "Setting ownership to $WEB_USER:$WEB_USER..."
chown -R $WEB_USER:$WEB_USER "$MOODLE_PATH"
chown -R $WEB_USER:$WEB_USER "$MOODLEDATA_PATH"

print_status "Setting permissions..."
chmod -R 755 "$MOODLE_PATH"
chmod -R 770 "$MOODLEDATA_PATH"
find "$MOODLEDATA_PATH" -type d -exec chmod 770 {} \;
find "$MOODLEDATA_PATH" -type f -exec chmod 660 {} \;

# Verify permissions
if sudo -u $WEB_USER test -w "$MOODLEDATA_PATH/data"; then
    print_status "✓ Permissions verified - $WEB_USER can write to moodledata"
else
    print_error "$WEB_USER cannot write to moodledata!"
    exit 1
fi

# ============================================
# CLEAR CACHES
# ============================================
print_section "STEP 10: Clearing Caches"

print_status "Clearing cache directories..."
rm -rf "${MOODLEDATA_PATH}/cache/"* 2>/dev/null || true
rm -rf "${MOODLEDATA_PATH}/localcache/"* 2>/dev/null || true
rm -rf "${MOODLEDATA_PATH}/temp/"* 2>/dev/null || true
rm -rf "${MOODLEDATA_PATH}/sessions/"* 2>/dev/null || true
print_status "✓ Caches cleared"

# ============================================
# CHECK DATABASE & UPGRADE (IF NEEDED)
# ============================================
print_section "STEP 11: Database Upgrade"

print_status "Checking database status..."

# Check if database has tables
TABLE_COUNT=$(PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public';" 2>/dev/null | tr -d ' ')

if [ -z "$TABLE_COUNT" ] || [ "$TABLE_COUNT" -eq "0" ]; then
    print_warning "Database is empty - fresh installation detected"
    print_status "Skipping database upgrade (will be done via web installer)"
    
    # Extract domain from config.php - try multiple patterns
    # Pattern 1: Direct hostname variable
    SITE_URL=$(grep -oP "(?<=\\\$hostname\s{0,}=\s{0,}')[^']+" "${MOODLE_PATH}/config.php" 2>/dev/null)
    if [ -n "$SITE_URL" ]; then
        # Check if it starts with http, if not add https://
        if [[ ! "$SITE_URL" =~ ^https?:// ]]; then
            SITE_URL="https://$SITE_URL"
        fi
    else
        # Pattern 2: Try to get wwwroot directly (for simple configs)
        SITE_URL=$(grep -oP "(?<=\\\$CFG->wwwroot\s{0,}=\s{0,}')[^']+" "${MOODLE_PATH}/config.php" 2>/dev/null)
    fi
    
    # Fallback if nothing found
    if [ -z "$SITE_URL" ]; then
        SITE_URL="your-moodle-domain"
    fi
    
    echo ""
    echo -e "${YELLOW}┌─────────────────────────────────────────────────────────┐${NC}"
    echo -e "${YELLOW}│  Complete installation via web browser:                │${NC}"
    echo -e "${YELLOW}│  ${SITE_URL}${NC}"
    printf "${YELLOW}│%-57s│${NC}\n" ""
    echo -e "${YELLOW}│  The web installer will guide you through:             │${NC}"
    echo -e "${YELLOW}│  1. Environment checks                                  │${NC}"
    echo -e "${YELLOW}│  2. Database setup                                      │${NC}"
    echo -e "${YELLOW}│  3. Admin account creation                              │${NC}"
    echo -e "${YELLOW}│  4. Site configuration                                  │${NC}"
    echo -e "${YELLOW}└─────────────────────────────────────────────────────────┘${NC}"
    echo ""
else
    print_status "Database has $TABLE_COUNT tables - performing upgrade..."
    echo ""
    
    sudo -u $WEB_USER $PHP_BIN "${MOODLE_PATH}/admin/cli/upgrade.php" --non-interactive
    
    print_status "✓ Database upgrade completed"
fi

# ============================================
# FINALIZE
# ============================================
print_section "STEP 12: Finalizing"

print_status "Disabling maintenance mode..."
sudo -u $WEB_USER $PHP_BIN "${MOODLE_PATH}/admin/cli/maintenance.php" --disable 2>/dev/null || true

print_status "Purging all caches..."
sudo -u $WEB_USER $PHP_BIN "${MOODLE_PATH}/admin/cli/purge_caches.php"

# Cleanup
print_status "Cleaning up..."
rm -f "${BASE_PATH}/moodle-latest-500.tgz"
rm -f "${BASE_PATH}/moodle-5.0.tgz"
rm -rf /tmp/moodle

FINAL_AVAILABLE=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')

# Extract site URL from config for final message - handle multiple patterns
SITE_URL=$(grep -oP "(?<=\\\$hostname\s{0,}=\s{0,}')[^']+" "${MOODLE_PATH}/config.php" 2>/dev/null)
if [ -n "$SITE_URL" ]; then
    if [[ ! "$SITE_URL" =~ ^https?:// ]]; then
        SITE_URL="https://$SITE_URL"
    fi
else
    SITE_URL=$(grep -oP "(?<=\\\$CFG->wwwroot\s{0,}=\s{0,}')[^']+" "${MOODLE_PATH}/config.php" 2>/dev/null || echo "https://your-moodle-domain")
fi

echo ""
echo -e "${GREEN}========================================================${NC}"
echo -e "${GREEN}  ✓ INSTALLATION COMPLETE!${NC}"
echo -e "${GREEN}========================================================${NC}"
echo ""
echo -e "${BLUE}Summary:${NC}"
echo "  • Moodle Version: 5.0.3+ (Weekly Stable Build)"
echo "  • PHP Version: $PHP_VERSION"
echo "  • PostgreSQL Version: $PG_VERSION"
echo "  • Web Server User: $WEB_USER"
echo "  • Available Space: ${FINAL_AVAILABLE}GB"
echo ""
echo -e "${BLUE}Access your site:${NC}"
echo "  $SITE_URL"
echo ""
echo -e "${BLUE}Next Steps:${NC}"
echo "  1. Visit your site and login"
echo "  2. Check Site Administration → Plugins for updates"
echo "  3. Once satisfied, remove old installation:"
echo "     rm -rf ${MOODLE_PATH}.old"
echo ""
echo -e "${GREEN}Script completed successfully!${NC}"
echo ""