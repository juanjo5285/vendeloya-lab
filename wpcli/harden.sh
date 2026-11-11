#!/bin/sh
# Aplica los ajustes de seguridad de wp-config.php (H-18, H-14). Es repetible.
set -e
cd /var/www/html
wp config set DISALLOW_FILE_EDIT true --raw
wp config set DISALLOW_FILE_MODS true --raw
wp config set DISABLE_WP_CRON true --raw
wp config set WP_DEBUG false --raw
echo ">> wp-config.php endurecido:"
grep -nE "DISALLOW_FILE_EDIT|DISALLOW_FILE_MODS|DISABLE_WP_CRON|WP_DEBUG'" wp-config.php
