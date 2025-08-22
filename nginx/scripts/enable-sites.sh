#!/usr/bin/env sh
set -eu

mkdir -p /etc/nginx/sites-enabled

for file in /etc/nginx/sites-available/*.conf; do
  [ -e "$file" ] || continue
  base=$(basename "$file")
  # Try symlink first; if it fails (e.g., FS limitations), copy instead
  if ln -sf "/etc/nginx/sites-available/$base" "/etc/nginx/sites-enabled/$base" 2>/dev/null; then
    echo "Enabled $base (symlink)"
  else
    cp -f "/etc/nginx/sites-available/$base" "/etc/nginx/sites-enabled/$base"
    echo "Enabled $base (copied)"
  fi
done

nginx -t
exec nginx -g 'daemon off;'
