# Moodle Upgrade Guide: 4.2 to 4.5

## 1. Navigate to LMS Directory
```bash
cd data/content/lms
```

## 2. Backup Your Current Moodle Installation
```bash
mv moodle moodle.backup
```

## 3. Download Moodle 4.5
```bash
sudo wget https://download.moodle.org/download.php/direct/stable405/moodle-latest-405.tgz -O moodle-4.5.tgz
```

## 4. Extract the New Version
```bash
sudo tar xvzf moodle-4.5.tgz
```

## 5. Copy Configuration and Custom Files
> Copy your old config.php and custom plugins/themes (for fresh installs just copy the config.php)

```bash
cp moodle.backup/config.php moodle
cp -pr moodle.backup/theme/mytheme moodle/theme/mytheme
cp -pr moodle.backup/mod/mymod moodle/mod/mymod
```

## 6. Update File Ownership
> Change ownership from nginx to apache (the actual web server user)

```bash
chown -R apache:apache /data/content/lms/moodle
chown -R apache:apache /data/content/lms/moodledata
```

## 7. Set Correct Permissions
```bash
chmod -R 755 /data/content/lms/moodle
chmod -R 770 /data/content/lms/moodledata
find /data/content/lms/moodledata -type d -exec chmod 770 {} \;
find /data/content/lms/moodledata -type f -exec chmod 660 {} \;
```

## 8. Verify Apache Access
> Verify apache can access it now

```bash
sudo -u apache test -r /data/content/lms/moodledata/data && echo "✓ Readable" || echo "✗ Cannot read"
sudo -u apache test -w /data/content/lms/moodledata/data && echo "✓ Writable" || echo "✗ Cannot write"
```

## 9. Restart Services
> Restart PHP-FPM and Nginx

```bash
systemctl restart php82-php-fpm
systemctl restart nginx
```