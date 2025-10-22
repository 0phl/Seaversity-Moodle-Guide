# Quick Domain Setup Guide

A fast reference for converting your Moodle from IP to domain access.

### Step 1: DNS Configuration 

**Cloudflare:**
1. Dashboard → Your domain → DNS
2. Add record:
   - Type: `A`
   - Name: `moodle` (or your subdomain)
   - IPv4: `YOUR_SERVER_IP`
   - Proxy: ON (orange cloud)
3. Save

**Wait 5-10 minutes for DNS propagation**

---

### Step 2: Update Moodle config.php 

```bash
# Backup first
cp /var/www/moodle/config.php /var/www/moodle/config.php.backup

# Edit config
nano /var/www/moodle/config.php
```

**Find this:**
```php
$hostname = '';
```

**Change to:**
```php
$hostname = 'moodle.yourdomain.com';  // Your actual domain
```

**Or if you don't have the $hostname variable, find:**
```php
$CFG->wwwroot = 'http://YOUR_IP';
```

**Change to:**
```php
$CFG->wwwroot = 'https://moodle.yourdomain.com';
$CFG->sslproxy = true;  // Add this line for Cloudflare
```

Save: `Ctrl+X`, `Y`, `Enter`

---

### Step 3: Update Nginx (2 minutes)

```bash
# Backup first
cp /etc/nginx/conf.d/moodle.conf /etc/nginx/conf.d/moodle.conf.backup

# Edit Nginx config
nano /etc/nginx/conf.d/moodle.conf
```

**Find:**
```nginx
server_name YOUR_IP _;
```

**Change to:**
```nginx
server_name moodle.yourdomain.com;
```

**Test and restart:**
```bash
nginx -t
systemctl restart nginx
```

---

### Step 4: Install SSL Certificate (3 minutes)

```bash
# Install Certbot (if not installed)
dnf install -y certbot python3-certbot-nginx

# Get certificate
certbot --nginx -d moodle.yourdomain.com
```

**Follow prompts:**
1. Email: `your-email@example.com`
2. Agree to terms: `Y`
3. Share email with EFF: `Y` or `N` (doesn't matter)
4. Redirect HTTP to HTTPS: `2`

---

### Step 5: Configure Cloudflare SSL (1 minute)

**If using Cloudflare:**

1. Cloudflare Dashboard → Your domain
2. SSL/TLS → Overview
3. **BEFORE SSL on server:** Set to `Flexible`
4. **AFTER SSL installed:** Change to `Full (Strict)`

---

## Verification

```bash
# Test DNS
nslookup moodle.yourdomain.com

# Test SSL
curl -I https://moodle.yourdomain.com

# Check certificate
certbot certificates

# Clear Moodle cache
sudo -u nginx php /var/www/moodle/admin/cli/purge_caches.php
```
