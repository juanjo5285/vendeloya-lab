#!/bin/sh
# Instala WordPress, los plugins de la Tabla 3 y los cuatro perfiles de la Tabla 1.
set -e
cd /var/www/html

echo ">> Esperando la base de datos..."
until php -r 'mysqli_report(MYSQLI_REPORT_OFF); exit(@mysqli_connect("db", getenv("WORDPRESS_DB_USER"), getenv("WORDPRESS_DB_PASSWORD"), getenv("WORDPRESS_DB_NAME")) ? 0 : 1);' >/dev/null 2>&1; do sleep 3; done

if wp core is-installed >/dev/null 2>&1; then
  echo ">> WordPress ya está instalado. Nada que hacer."
  exit 0
fi

echo ">> Instalando WordPress..."
wp core install \
  --url="$SITE_URL" \
  --title="VendeloYa (laboratorio)" \
  --admin_user="$ADMIN_USER" \
  --admin_password="$ADMIN_PASSWORD" \
  --admin_email="$ADMIN_EMAIL" \
  --skip-email

wp rewrite structure '/%postname%/' --hard

echo ">> Instalando plugins de la línea base..."
wp plugin install \
  woocommerce \
  woocommerce-gateway-stripe \
  elementor \
  wordpress-seo \
  wp-mail-smtp \
  wp-fastest-cache \
  wp-2fa \
  updraftplus \
  capability-manager-enhanced \
  --activate

echo ">> Creando usuarios por perfil..."
wp user create desarrollador desarrollador@vendeloya.test --role=administrator --user_pass="$USER_PASSWORD"
wp user create editor editor@vendeloya.test --role=editor --user_pass="$USER_PASSWORD"
wp user create cliente cliente@vendeloya.test --role=customer --user_pass="$USER_PASSWORD"

echo ">> Listo. Sitio: $SITE_URL  |  Admin: $SITE_URL/wp-admin"