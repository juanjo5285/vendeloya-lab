# Laboratorio endurecido (antes y después)

Estos archivos se copian a la raíz del repositorio `vendeloya-lab`, junto a los que ya existen.
**No se ha probado en un entorno real**: si algo no arranca, mira la sección "Problemas probables".

## Qué aplica
| Control | Hallazgo | Dónde |
|---|---|---|
| WAF ModSecurity con OWASP CRS, HTTP en 8080 y HTTPS autofirmado en 8443 | H-24, H-01 | servicio `waf` |
| Ingress sin puerto publicado (solo la WAF lo alcanza) | H-23 | `ingress` |
| Base de datos sin puerto publicado y en red interna | H-20, H-21 | `db`, red `backend` |
| Bloqueo de `xmlrpc.php`, `wp-cron.php`, `readme.html`, `?author=N` y usuarios por REST sin sesión | H-14 | `nginx/hardened.conf` |
| Límite de intentos de login y de pago, y límite general por IP | H-15, H-10, H-25 | `nginx/hardened.conf` |
| Cabeceras de seguridad y CSP en modo informe; sin `X-Powered-By` ni versiones de Apache y PHP | H-07 | `nginx/`, `php/`, `apache/` |
| `DISALLOW_FILE_EDIT`, `DISALLOW_FILE_MODS`, `DISABLE_WP_CRON` | H-18 | `wpcli/harden.sh` |
| Contenedores con `no-new-privileges`, capacidades mínimas, solo lectura y límites de recursos | H-17 | `docker-compose.hardened.yml` |

## Qué NO aplica (se hace aparte)
- 2FA obligatorio (H-08): en WP 2FA > Policies.
- Rol Desarrollador sin permisos de plugins (H-09): en Capabilities.
- Contenedores sin root: es una mejora opcional que requiere imagen propia.
- TLS entre WordPress y MySQL, claves en Key Vault y todo lo propio de Azure: se documenta como diseño.

## Paso a paso
1. Copia los archivos de este zip a la raíz de `vendeloya-lab` (carpetas `nginx`, `wpcli`, `php`, `apache` y los archivos sueltos).
2. **Antes**: con el laboratorio en su estado de línea base (`docker compose up -d`), ejecuta
   `powershell -ExecutionPolicy Bypass -File .\verificar.ps1 -Etiqueta antes`
   y guarda también una captura del escaneo de ZAP y de `nmap -p 3306,8080 127.0.0.1`.
3. **Activar**:
   ```powershell
   docker compose -f docker-compose.hardened.yml up -d --remove-orphans
   docker compose -f docker-compose.hardened.yml run --rm hardener /harden.sh
   ```
   Entra a http://localhost:8080 y comprueba que la tienda y el panel funcionan.
4. **Después**: `powershell -ExecutionPolicy Bypass -File .\verificar.ps1 -Etiqueta despues` y repite el escaneo de ZAP.
5. **Comparar** los dos archivos de `evidencias\` (son los números del "antes y después" del informe).

## Qué debería cambiar
| Prueba | Antes | Después (esperado) |
|---|---|---|
| xmlrpc.php | 405 | 403 |
| wp-json/wp/v2/users sin sesión | 200 | 403 |
| wp-cron.php | 200 | 403 |
| readme.html | 200 | 403 |
| ?author=1 | 301 | 403 |
| XSS y SQLi en un parámetro | 200 | 403 (WAF) |
| 12 logins seguidos | todos 200 | 200 y luego 429 |
| Puerto 3306 | abierto | cerrado |
| Cabeceras | `X-Powered-By`, sin cabeceras de seguridad | sin `X-Powered-By`, con cabeceras de seguridad |

Si un valor "después" no coincide, **anota lo que obtuviste**: es el resultado real y es lo que va al informe.

Pruebas extra de contenedores y red (guarda la salida):
```powershell
docker inspect --format "{{.HostConfig.ReadonlyRootfs}} {{.HostConfig.CapDrop}} {{.HostConfig.SecurityOpt}}" vendeloya-lab-wp1-1
docker compose -f docker-compose.hardened.yml exec wp1 grep -n DISALLOW /var/www/html/wp-config.php
docker compose -f docker-compose.hardened.yml exec ingress getent hosts db      # no debe resolver
curl.exe -kI https://localhost:8443/
nmap -sV --script ssl-enum-ciphers -p 8443 127.0.0.1
```
Bloqueos de la WAF: `docker compose -f docker-compose.hardened.yml logs waf --tail 50`.

## Volver a la línea base
```powershell
docker compose -f docker-compose.hardened.yml run --rm hardener /unharden.sh
docker compose -f docker-compose.yml up -d --remove-orphans
```

## Problemas probables
- **`wp1` o `wp2` no arrancan**: mira `docker compose -f docker-compose.hardened.yml logs wp1`. Prueba comentando primero `read_only` y sus `tmpfs`, y después `cap_drop` y `cap_add`.
- **La WAF no responde o el puerto 8080 está ocupado**: `docker compose -f docker-compose.hardened.yml ps` y revisa `logs waf`. Si el contenedor `ingress` anterior sigue usando el 8080, ejecuta `docker compose down` y vuelve a levantar. Los nombres de las variables de entorno de la imagen `owasp/modsecurity-crs:nginx` conviene confirmarlos en su documentación.
- **El panel de WordPress da 403 al guardar**: son falsos positivos de la WAF. Cambia `MODSEC_RULE_ENGINE` a `DetectionOnly`, revisa el registro y anota qué regla saltó (también es un resultado útil para el informe).
- **Las tareas programadas de WooCommerce dejan de ejecutarse** por `DISABLE_WP_CRON`: es esperado en el laboratorio; en producción se programa un cron real.
- **No se pueden instalar plugins desde el panel** por `DISALLOW_FILE_MODS`: es el efecto buscado. Para instalar, ejecuta `unharden.sh`, instala y vuelve a endurecer.
