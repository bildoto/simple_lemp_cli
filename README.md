# simple_lemp_cli v3 — isolation edition (candidate)

This version builds on the existing project, retaining the `site` interactive menu, DNS/status/check, additional databases, credentials, and Basic Auth commands.

## Install

The intended workflow is **push the complete project to GitHub**, then download only `install.sh` to the Debian server. The installer downloads the entire repository archive and installs the scripts, shared library and status-page asset.

```bash
curl -fsSL https://raw.githubusercontent.com/bildoto/simple_lemp_cli/main/install.sh -o /tmp/simple-lemp-install.sh
sudo bash /tmp/simple-lemp-install.sh
sudo site
```

The bootstrap expects the repository's **main** branch to contain the new v3 files. Commit and push the v3 project **before** running it, otherwise you will install whatever is currently on GitHub. To use a different branch, set `SITE_MANAGER_REF=branch-name` for the `sudo bash` invocation. If the complete project has already been extracted locally, use `sudo bash ./install.sh --local` instead.

**Test on a disposable Debian/PHP 8.4 VM first.** Check installed packages and Nginx before installation. Back up existing scripts and configs. This fetches and executes administrative code from GitHub as root: use only a repository/branch you control and trust. Pinning a release commit and verifying its checksum would be stronger for production.

## Interactive administration (`site` is the primary interface)

Run **`sudo site`** to administer the server. You do **not** need to invoke the individual `site-*` utilities in normal use; they are implementation helpers used by the menu. They remain installed and directly callable for scripting and troubleshooting.

The initial site list provides separate entries for **Create site (with SSL)** and **Create site (without SSL)**; both invoke the same underlying provisioning script with different arguments. Select an existing site to manage enabling/disabling, credentials, databases, DNS, Basic Auth, SSL, identity information and deletion. **Enable** and **Disable** are separate site actions. **Delete site** offers preview and permanent removal with explicit confirmation; it never silently performs a disable-only action. The menu also provides a server-prerequisite check.

If you deliberately want noninteractive automation, the equivalent commands remain supported:

```bash
sudo site create example.com
sudo site create example.com --no-ssl
sudo site ssl example.com
```

For an HTTP-only site, request SSL later from that site's **Configure / retry Let's Encrypt SSL** menu entry after DNS becomes available.

The site user/group, MariaDB primary user and PHP-FPM pool share a fixed 16-character name such as `s_tilmpa_ead4431`. The full database name is descriptive and shortened to <=64 characters where necessary. `.co.uk` has a limited special case. For other compound public suffixes, set `SITE_BASE_DOMAIN=example.co.xx` when creating the site; the generated identity is saved, not recalculated.

The site is created under `/srv/www/example.com` with a dedicated PHP-FPM pool and **site-user-owned files, using ordinary Unix permissions and no ACLs**. `public/` is readable to Nginx and other local site users; private credentials must live outside `public/` as `600` files. `var/` remains private at `700`. The website PHP process can now modify its own source files: this is a deliberate simplicity-versus-security trade-off. See [FILE-PERMISSIONS.md](FILE-PERMISSIONS.md) for deployment instructions and the migration procedure for legacy ACL-based sites.

Each site has three Nginx configuration includes under `/etc/nginx/site-manager/example.com/`: `protection.conf`, `routes.conf`, `php.conf` in that order. Certificates are managed by Certbot's Nginx installer. **Review application routing and equivalent Apache `.htaccess` restrictions before publishing**. Protected PHP endpoints use exact locations; protected directories use `^~` with a nested PHP handler. Test protected URLs and alternative application routes. Config editing is validated via `nginx -t`.

## Manage databases

From `sudo site`, select a website and choose **Manage databases**. The menu displays each database’s live privilege level at the top, along with creation/deletion and a single privilege toggle for the selected database. The same account may own several site databases; permissions are adjusted **per database**, not globally.

New primary and additional databases start restricted to `SELECT`, `INSERT`, `UPDATE`, and `DELETE`. For installation and migrations, use **Change database privilege level** to elevate, and select it again afterward to restrict. Elevation grants `ALL PRIVILEGES` only on the selected database, never globally or with `GRANT OPTION`. The command requires an explicit confirmation. These database-level operations do not remove any independently granted global or table-specific privileges; review unusual/custom grants separately.

Command-line automation is also available through `sudo site database-privileges example.com list|toggle|elevate|restrict [database]`.

## Databases

Additional databases are recorded explicitly in `/etc/site-manager/sites/example.com.databases` (tab-separated database, username, separate-user flag), not inferred from name prefixes. They can share the main site DB user or use a separate user. The separate account grants privileges only to its own database. Site deletion checks this registry. Avoid modifying it manually.

## Deletion

- `sudo site-delete example.com` displays resources (dry run).
- `sudo site-disable example.com` activates a 503 maintenance virtual host while preserving files, database and PHP-FPM pool. HTTPS uses the existing Let's Encrypt certificate, if present. Certificate renewal for disabled sites must be verified with `certbot renew --dry-run`; the ACME challenge path is reserved but renewal plugin behavior varies. Use `sudo site-enable example.com` to re-enable it. Both commands validate and attempt to roll back if Nginx testing/reload fails.
- `sudo site-delete example.com --confirm` is intentionally rejected; deletion requires `--purge-data`.
- `sudo site-delete example.com --confirm --purge-data` permanently removes site resources and its registered additional databases (and cron). Certificate material is not removed automatically.

## Limitations and testing

This package has **not been fully validated on a running Debian/Nginx/PHP-FPM/MariaDB host**. Bash syntax checks are not runtime integration tests. Do not replace a production installation until test sites have been created and protected resources verified over HTTP. Pending issues include hardened automatic rollback after every possible failure, script reconciliation with existing deployed sites, and ensuring every application deployment sets correct ownership and private credential permissions.

Cron tasks should run as each site's dedicated user. Avoid PHP-executable uploads, and keep each site's DB credentials inaccessible to other site users.

### Cron jobs (interactive)

Select a site in `sudo site`, then choose **[13] Manage cron jobs**.
The submenu provides **Edit cron jobs** and **List cron jobs** for that site's
dedicated Linux user. The account is resolved from the site's root-owned
registration record; you never need to enter the generated username.

The editor uses Debian's regular `crontab -u USER -e`. An empty crontab is
reported as "No cron jobs configured." Invalid choices and editor failures
return to the menu rather than exiting `site`. Use absolute paths in jobs,
and store outputs in a directory the site user can write (such as `var/`).

Cron jobs are **not** automatically added on site creation or removed by
this menu. Site deletion remains responsible for cleaning up that site's
crontab when deleting the Linux account.

## File ownership and deployment (Unix permissions)

New sites use the simpler **site-owned, non-ACL** ownership model. PHP-FPM and site cron jobs run as a dedicated account; Nginx can serve static assets under `public/`, and secrets belong outside `public/` in private files/directories. Application files are writable by their own PHP user; this trades source-code immutability for straightforward deployment.

**Read [FILE-PERMISSIONS.md](FILE-PERMISSIONS.md) before deploying applications or converting an existing site.** It includes sample modes, deployment commands, credential placement, upload guidance, trade-offs and verification steps.

The selected-site menu has an advanced **Reset site file permissions** action to convert legacy ACL-based sites. It requires explicit confirmation and must not be used blindly on sites with custom writable directories or symlinks. Routine deployments should instead run under the dedicated site user.
