#!/usr/bin/env bash
set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/bildoto/simple_lemp_cli/main"
SCRIPT_RAW="$REPO_RAW/scripts"
ASSET_RAW="$REPO_RAW/assets"

TARGET_DIR="/usr/local/sbin"
ASSET_DIR="/opt/simple-lemp-cli"

SCRIPTS=(
  site
  site-create
  site-enable
  site-disable
  site-delete
  site-credentials
  site-database-create
  site-database-delete
  site-dns
  site-protect
  site-unprotect
  site-protect-user-add
  site-protect-user-remove
  site-status
  site-check
)

if [[ "$EUID" -ne 0 ]]; then
    echo "Run as root."
    exit 1
fi

echo "Installing required packages..."

apt update

apt install -y \
  nginx \
  mariadb-server \
  php-fpm \
  php-mysql \
  certbot \
  python3-certbot-nginx \
  apache2-utils \
  wget \
  openssl

echo
echo "Installing site tools..."

for script in "${SCRIPTS[@]}"; do
    echo "Installing $script..."

    tmpfile="$(mktemp)"

    wget -qO "$tmpfile" "$SCRIPT_RAW/$script"

    sed 's/\r$//' "$tmpfile" > "$TARGET_DIR/$script"
    rm "$tmpfile"

    chmod 755 "$TARGET_DIR/$script"
    bash -n "$TARGET_DIR/$script"
done

echo
echo "Installing reusable assets..."

mkdir -p "$ASSET_DIR/status"

if wget -qO "$ASSET_DIR/status/index.php" "$ASSET_RAW/status/index.php"; then
    chmod 644 "$ASSET_DIR/status/index.php"
else
    echo "Warning: could not install status page asset."
fi

mkdir -p /srv/www
mkdir -p /root/site-credentials
chmod 700 /root/site-credentials

echo
echo "Running site-check..."
echo

site-check

echo
echo "Installed."
echo
echo "Run:"
echo "  site"