# Simulación de Azure para VendeloYa (sin despliegue)

Esta carpeta contiene infraestructura como código **escrita pero no desplegada**.
No se crea ningún recurso en Azure ni se usa una suscripción real.

- `terraform/`: red privada, AKS privado con RBAC de Entra ID, MySQL flexible en subred delegada,
  Key Vault sin acceso público, almacenamiento de respaldos y política WAF (OWASP 3.2, modo prevención).
- `kubernetes/`: espacio de nombres con Pod Security `restricted`, despliegue de WordPress sin root con
  sistema de archivos de solo lectura y políticas de red que niegan todo por defecto.

Los secretos no se escriben aquí: `db_admin_password` se pasa por variable. Los valores `0000...` son marcadores.
Estado de la validación: los archivos se evalúan con Checkov en la integración continua (`seguridad-ci`).
