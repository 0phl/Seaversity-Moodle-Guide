# Moodle Server Configuration on Rocky Linux 9

## 1. Install the PGDG Repository

The PostgreSQL Yum Repository RPM will allow you to install specific versions of PostgreSQL.

```bash
sudo dnf install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-9-x86_64/pgdg-redhat-repo-latest.noarch.rpm
```

## 2. Disable the Default PostgreSQL Module

Rocky Linux 9 (and other RHEL-based systems) includes a default PostgreSQL module. You must disable it to avoid conflicts and ensure you install version 15 from the PGDG repository.

```bash
sudo dnf -qy module disable postgresql
```

## 3. Install PostgreSQL 15

Now you can install the PostgreSQL 15 server package using dnf.

```bash
sudo dnf install -y postgresql15-server postgresql15-contrib
```

## 4. Initialize the Database Cluster

Before starting the service, you need to create a new database cluster.

```bash
sudo /usr/pgsql-15/bin/postgresql-15-setup initdb
```

## 5. Start and Enable the PostgreSQL Service

Use systemctl to start the PostgreSQL 15 service and enable it to start automatically at boot.

```bash
sudo systemctl enable postgresql-15
sudo systemctl start postgresql-15
```

### Troubleshooting PostgreSQL Port Conflicts

If you encounter an error when starting PostgreSQL, another process might already be using the standard PostgreSQL port (5432).

#### Check which process is using port 5432:

```bash
sudo ss -tuln | grep 5432
```

#### Find the PID with fuser:

```bash
sudo fuser 5432/tcp
```

#### Terminate the Conflicting Process

If the PID of the rogue process running on port 5432 is showing (e.g., 779), use the kill command to forcefully stop the process:

```bash
sudo kill -9 779
```

Replace 779 with the actual PID shown in your system.

#### Test and Start PostgreSQL Again

After terminating the conflicting process, test and start PostgreSQL again:

```bash
sudo -i -u postgres
psql
```

#### Create Moodle Database

Once PostgreSQL is running, create the Moodle database:

```sql
CREATE DATABASE moodle 
WITH ENCODING 'UTF8' 
LC_COLLATE='en_US.utf8' 
LC_CTYPE='en_US.utf8' 
TEMPLATE=template0;

CREATE USER moodleuser WITH PASSWORD 'Seaversity@2025';

ALTER DATABASE moodle OWNER TO moodleuser;
```

#### List All Databases and Database Roles

```sql
postgres=# \l
postgres=# \du
```

## 6. Configure Moodle

Navigate to the Moodle directory and edit the configuration file:

```bash
cd data/content/lms/moodle
vi config.php
```

### Update Database Credentials

Change these values to match your database credentials:

```php
$CFG->dbname    = 'sample';
$CFG->dbuser    = 'ron_moodle';
$CFG->dbpass    = 'ron123test';
```

### Configure Hostname

Update the hostname definition:

```php
// Hostname definition //
$hostname = 'ronan.seaversity.com.ph'; # change this to your domain
if ($hostname == '') {
  $hostwithprotocol = 'https://loadbalancer';
}
else {
  $hostwithprotocol = 'https://' . strtolower($hostname);
}
```

## 7. Configure Nginx

Navigate to the Nginx sites-enabled directory:

```bash
cd /etc/nginx/sites-enabled/
vi lms.conf
```

Change the `server_name` to your domain:

```bash
cat /etc/nginx/sites-enabled/lms.conf
```

### Restart Nginx and Check Status

```bash
nginx -T
systemctl restart nginx
```

## 8. Configure NPMPlus

1. Go to NPMPlus
2. Add proxy host
3. Enter your domain
4. Add your IP address (check it via terminal with `ip a` to get the inet IP)
5. Add port 80
6. Enable WebSocket support and save

## 9. Configure Cloudflare

1. Go to your Seaversity domain and DNS records
2. Add a new record with the following settings:
   - Type: CNAME
   - Name: ronan (example: ronan.seaversity.com.ph)
   - Target: staging---.seaversity.com.ph

## 10. Test Server Reachability and Configure TLS

1. Go to NPMPlus TLS certificate section
2. Add TLS certificate (Certbot)
3. Enter your domain and test server reachability

When the server is reachable:

1. Go back to proxy host
2. Search for your domain and edit
3. Go to TLS section
4. Request a new TLS certificate
5. Enable Force HTTPS
6. Enable Brotli
7. Enable HTTP/3-Quic
8. Save

---

**Note:** Add comments to ensure safe practice and organize your work.
