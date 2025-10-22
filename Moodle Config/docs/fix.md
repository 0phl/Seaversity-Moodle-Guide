# The Issue

PHP-FPM and Nginx run as apache (not nginx)
You set ownership to nginx:nginx but the web server runs as apache
Parent directories owned by webapp:apache with 770 permissions
The nginx user cannot access anything!

# The Fix

```bash
# Change ownership from nginx to apache (the actual web server user)
chown -R apache:apache /data/content/lms/moodle
chown -R apache:apache /data/content/lms/moodledata

# Set correct permissions
chmod -R 755 /data/content/lms/moodle
chmod -R 770 /data/content/lms/moodledata
find /data/content/lms/moodledata -type d -exec chmod 770 {} \;
find /data/content/lms/moodledata -type f -exec chmod 660 {} \;

# Verify apache can access it now
sudo -u apache test -r /data/content/lms/moodledata/data && echo "✓ Readable" || echo "✗ Cannot read"
sudo -u apache test -w /data/content/lms/moodledata/data && echo "✓ Writable" || echo "✗ Cannot write"

# Restart PHP-FPM and Nginx
systemctl restart php82-php-fpm
systemctl restart nginx
