#!/bin/sh
# Revierte los ajustes de wp-config.php para volver a la línea base.
cd /var/www/html
for k in DISALLOW_FILE_EDIT DISALLOW_FILE_MODS DISABLE_WP_CRON; do
  wp config delete "$k" 2>/dev/null || true
done
wp config set WP_DEBUG false --raw 2>/dev/null || true
echo ">> wp-config.php en estado de línea base"
