# Laboratorio local VendeloYa (línea base)

Laboratorio con Docker que reproduce la arquitectura de **línea base** de VendeloYa (tienda WordPress + WooCommerce).
Mantiene a propósito las configuraciones predeterminadas, que son inseguras, para poder evaluarlas.
**No usar en producción ni exponer a Internet.**

## Requisitos
- Docker Desktop (o Docker Engine con Compose v2), con al menos 4 GB de RAM asignados.
- Git.
- Conexión a Internet en el primer arranque (descarga de imágenes y plugins).

## Puesta en marcha

```powershell
git clone https://github.com/TU_USUARIO/vendeloya-lab.git
cd vendeloya-lab
copy .env.example .env        # en Linux/macOS: cp .env.example .env
```

Abre `.env` y cambia los valores `CAMBIAR` por claves de laboratorio. Ese archivo **no se sube a Git**.

```powershell
docker compose up -d           # el primer arranque tarda unos minutos
docker compose logs -f wpcli   # termina con ">> Listo. Sitio: http://localhost:8080"
```

- Tienda: http://localhost:8080
- Panel: http://localhost:8080/wp-admin (usuario y clave en tu `.env`)

Reiniciar desde cero (borra la base y los archivos del sitio):

```powershell
docker compose down -v
```

## Qué se instala
- **Servicios:** `ingress` (nginx), `wp1` y `wp2` (WordPress `latest`), `db` (MySQL 8.0) y `wpcli` (instalación automática, corre una sola vez).
- **Plugins de la línea base:** WooCommerce, WooCommerce Stripe Payment Gateway, Elementor, Yoast SEO, WP Mail SMTP, WP Fastest Cache, WP 2FA, UpdraftPlus y PublishPress Capabilities.
- **Usuarios:** `propietario` (administrador), `desarrollador`, `editor` y `cliente`.

El asistente de configuración de WooCommerce puede instalar plugins que no pertenecen a la línea base (Jetpack, Klaviyo, PayPal Payments). Si aparecen en **Plugins**, desactívalos y elimínalos.

## Respaldo y restauración
Los respaldos y la carpeta `wp-content` **no se suben a Git**: contienen usuarios, pedidos y configuración.

```powershell
# Respaldo
docker compose exec -T db sh -c 'mysqldump -uroot -p$MYSQL_ROOT_PASSWORD --single-transaction wordpress > /tmp/respaldo.sql'
docker compose cp db:/tmp/respaldo.sql .\respaldo.sql
docker compose cp wp1:/var/www/html/wp-content .\wp-content

# Restaurar la base
docker compose cp .\respaldo.sql db:/tmp/respaldo.sql
docker compose exec -T db sh -c 'mysql -uroot -p$MYSQL_ROOT_PASSWORD wordpress < /tmp/respaldo.sql'
```

## Análisis automático (GitHub Actions)
El flujo `.github/workflows/seguridad.yml` se ejecuta en cada `push` y también a mano (pestaña **Actions → seguridad-ci → Run workflow**). Descarga los plugins de la línea base y ejecuta:

| Herramienta | Qué analiza | Archivo de salida |
|---|---|---|
| Semgrep | Código PHP de los plugins (SAST) | `semgrep_plugins.txt` |
| Trivy | Dependencias y secretos en los plugins (SCA) | `trivy_plugins.txt` |
| Trivy | Imágenes `wordpress:latest`, `mysql:8.0` y `nginx:stable` | `trivy_imagen_*.txt` |
| Checkov | Archivos de infraestructura como código del repositorio | `checkov.txt` |

Los reportes quedan como artefacto **evidencias-seguridad** al final de cada ejecución (se conservan 30 días). Las imágenes con etiqueta `latest` cambian con el tiempo: anota la fecha de cada resultado (`fecha_ejecucion.txt`).

## Equivalencias local ↔ Azure

| Componente de la línea base | En este laboratorio | En Azure |
|---|---|---|
| Cloudflare (SSL Flexible, sin WAF) | No incluido; todo viaja por HTTP | Se configura en Cloudflare |
| Ingress NGINX con IP pública | Contenedor `ingress` (puerto 8080) | Ingress NGINX en AKS |
| WordPress `latest`, 2 réplicas, root, xmlrpc activo | `wp1` y `wp2` | Deployment con 2 réplicas |
| MySQL 8.0 con acceso público | `db` con el puerto 3306 publicado | Azure Database for MySQL Flexible Server |
| Azure Files (uploads) | Volumen compartido `wp_html` | Azure Files |
| Secrets de Kubernetes | Variables en `.env` | Secrets de Kubernetes |
| ACR, Entra ID/RBAC, API server, AKS, Azure Monitor | No reproducibles en local | Solo en Azure |

## Qué se puede probar en local
`/wp-login.php`, `/wp-admin`, `/xmlrpc.php`, `/wp-json/wp/v2/users`, `/wp-cron.php`, la API Store de WooCommerce, el puerto 3306 y las cabeceras HTTP.

## Qué no se puede probar en local
Los hallazgos propios de Azure y Cloudflare: AKS, ACR, RBAC, Azure Files por clave y el tramo Cloudflare → ingress.

## Estructura
```
docker-compose.yml          Servicios del laboratorio
nginx/default.conf          Ingress de línea base
wpcli/setup.sh              Instalación de WordPress, plugins y usuarios
.env.example                Plantilla de variables (copiar a .env)
.github/workflows/          Análisis automático de seguridad
```
