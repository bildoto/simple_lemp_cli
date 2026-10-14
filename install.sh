#!/usr/bin/env bash
set -Eeuo pipefail
[[ $EUID -eq 0 ]] || { echo 'Run installer as root' >&2; exit 1; }
# Install directly from GitHub when this script was downloaded on its own.
# An extracted checkout can still be installed locally with --local.
BASE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
if [[ "${1:-}" != "--local" && ! -f "$BASE/lib/site-common" ]]; then
    REPO="${SITE_MANAGER_REPO:-bildoto/simple_lemp_cli}"
    REF="${SITE_MANAGER_REF:-main}"
    # Keep the repository/ref explicit and reject surprising characters.
    [[ "$REPO" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || { echo 'Invalid repository' >&2; exit 1; }
    [[ "$REF" =~ ^[A-Za-z0-9_.-]+$ ]] || { echo 'Invalid Git ref' >&2; exit 1; }
    command -v curl >/dev/null || { echo 'curl is required to download the repository' >&2; exit 1; }
    command -v tar >/dev/null || { echo 'tar is required to unpack the repository' >&2; exit 1; }
    TMPDIR_INSTALL="$(mktemp -d)"
    trap 'rm -rf "$TMPDIR_INSTALL"' EXIT
    URL="https://github.com/$REPO/archive/refs/heads/$REF.tar.gz"
    echo "Downloading $REPO ($REF) from GitHub..."
    curl -fLSs --retry 2 "$URL" -o "$TMPDIR_INSTALL/source.tar.gz"
    tar -xzf "$TMPDIR_INSTALL/source.tar.gz" -C "$TMPDIR_INSTALL"
    # A GitHub branch archive should contain exactly one repository root.
    mapfile -t INSTALLERS < <(find "$TMPDIR_INSTALL" -mindepth 2 -maxdepth 2 -name install.sh -type f)
    [[ "${#INSTALLERS[@]}" -eq 1 ]] || { echo 'Archive does not contain exactly one installer' >&2; exit 1; }
    INSTALL_ROOT="$(dirname "${INSTALLERS[0]}")"
    [[ -f "$INSTALL_ROOT/lib/site-common" && -d "$INSTALL_ROOT/scripts" ]] || { echo 'Missing expected project files' >&2; exit 1; }
    bash "$INSTALL_ROOT/install.sh" --local
    exit $?
fi
[[ -f "$BASE/lib/site-common" && -d "$BASE/scripts" ]] || { echo 'Cannot find local project files' >&2; exit 1; }
apt-get update
apt-get install -y nginx mariadb-server php8.4-fpm php8.4-mysql certbot python3-certbot-nginx apache2-utils acl cron openssl
install -d -m 755 /usr/local/sbin /usr/local/lib/site-manager
install -m 644 "$BASE/lib/site-common" /usr/local/lib/site-manager/site-common
for script in "$BASE"/scripts/*; do
 [[ -f $script ]] || continue
 bash -n "$script"
 install -m 755 "$script" "/usr/local/sbin/$(basename "$script")"
done
install -d -m 700 /root/site-credentials /etc/site-manager/sites
install -d -m 755 /etc/nginx/site-manager /srv/www
install -d -m 755 /opt/simple-lemp-cli/status
install -m 644 "$BASE/assets/status/index.php" /opt/simple-lemp-cli/status/index.php
printf 'Installed local Site Manager v3. Run: sudo site\n'
