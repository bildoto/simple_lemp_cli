# Site Manager v3: file layout and permissions

This document describes the **standard Unix-permissions model**, without extended ACLs. It is intended for one administrator managing several mutually untrusted PHP applications on Nginx with a dedicated PHP-FPM pool and Linux user per website.

## Directory layout

For `example.com`, Site Manager provisions:

```text
/srv/www/example.com/                 siteuser:siteuser  711
├── config.php                       siteuser:siteuser  600  (optional private config)
├── public/                          siteuser:siteuser  755
│   ├── index.php                    siteuser:siteuser  644
│   └── assets/                      siteuser:siteuser  755
│       └── styles.css               siteuser:siteuser  644
└── var/                             siteuser:siteuser  700
    ├── uploads/                     siteuser:siteuser  700 (when created)
    └── cache/                       siteuser:siteuser  700 (when created)
```

The generated Linux account is a **non-login service account**. PHP-FPM and site cron jobs run as that account. Nginx runs as `www-data` and can traverse the site root and read `public/` files.

* **711** on the site root permits traversal when a path is known, but prevents directory listing by other accounts.
* **755/644** inside `public/` permits Nginx to serve static files. **Other local site users can also read these files.** Do not store database passwords, API keys, session secrets or private photos there.
* **700/600** above `public/` (apart from the site root) and inside `var/` protects private files from other site users.
* The site's PHP process **can modify its own source code**, unlike the previous root-owned/ACL model. Cross-site isolation is still enforced by dedicated service accounts and the private file modes. This is an explicit security trade-off.

The web server's `root` must remain `/srv/www/<domain>/public`, not `/srv/www/<domain>`.

## Keeping secrets outside public

Many PHP apps already load a file from the parent directory:

```php
require __DIR__ . '/../config.php';
```

Place the actual secret-bearing `config.php` in `/srv/www/example.com/config.php` (mode `600`, owner `siteuser`). Alternatively, keep it in `var/config.php` and use a public loader if the application requires one:

```php
<?php
require __DIR__ . '/../var/config.php';
```

Do **not** copy credential-bearing files into `public/`, even if they have a `.php` extension: PHP handler mistakes, backups and local cross-site reads could expose them.

`/root/site-credentials/<domain>.txt` remains an administrator-only copy of credentials. The application must use its own private configuration file.

## Deploying or updating an application

**Deploy as the site's Linux user, not as root**. The account can write its own `public/` tree. This avoids restoring numeric ownership from another server's archives.

To discover the site user from the menu, select **Site identity / information**. Or inspect the root-owned site record:

```bash
sudo site info example.com
```

For a `.tar.gz` archive containing files intended for `public/`, an administrator can run (replace `SITEUSER` with the displayed identity):

```bash
sudo -u SITEUSER tar --no-same-owner --no-same-permissions \
    -xzf /path/to/application.tar.gz \
    -C /srv/www/example.com/public
```

**Inspect archives before extraction.** Ensure there are no absolute paths, `../` components, surprising symlinks, or untrusted executable files. The archive may have a top-level directory and may not be ready to extract directly into `public/`.

For code checked out through Git, arrange for files to be created/updated as the site user, without running Git or Composer as root. Permissions from the source repository or application may need app-specific review. Avoid blanket `chmod -R 777` or `chown -R www-data`.

The generic permission reset command described below is intended for initial conversion or recovery, **not as a required step after every routine deployment**.

## Uploads, caches, and generated files

Prefer private storage under `var/`. The site PHP user can create and modify it, and an authorized PHP download endpoint can stream selected files to users.

For publicly served uploads, first review the application's existing path and add an explicit Nginx rule preventing PHP execution there. The default permissions model alone does **not** make a web-accessible upload location safe. Never open the entire `public/` tree for writes by unrelated accounts.

PHP may create runtime files with different modes depending on its `umask`; keep private configuration `600` and private storage directories `700`.

## Converting an existing ACL-based v3 site

A new **Reset site file permissions (advanced)** action is available within `sudo site` (or `sudo site permissions example.com --apply`). It:

1. Resolves the existing site account from Site Manager's root-owned registry.
2. Rejects symlinks in the site tree before proceeding.
3. Requires confirmation naming the domain.
4. Removes extended ACL entries, sets ownership to the site account, applies `711` to the site root, `755/644` in `public/`, and `700/600` everywhere else, including `var/`.

**Important:** The reset is intentionally broad and may break programs that need executable shell scripts, writable public subdirectories with special permissions, symlinks, or group-sharing arrangements. It does not understand an application's private files stored *inside* `public/`: those become readable to local accounts. **Back up and review the application before using it.** Do not run it on established upload-driven applications without identifying their writable paths.

The reset does not edit Nginx, MariaDB, PHP-FPM or cron configuration.

## Quick checks

Use `namei -l`, `ls -l` and `stat` to inspect ordinary Unix permissions:

```bash
namei -l /srv/www/example.com/public/index.php
ls -la /srv/www/example.com
sudo -u SITEUSER test -r /srv/www/example.com/config.php && echo 'site can read secret'
sudo -u OTHER_SITEUSER test -r /srv/www/example.com/config.php || echo 'other site denied'
sudo -u www-data test -r /srv/www/example.com/public/assets/styles.css && echo 'nginx can read CSS'
```

The second site's access to `public/index.php` may succeed in this simplified model. **Do not mistake public source readability for permission to read private configuration files.** Verify both directions for sensitive files under private paths.
