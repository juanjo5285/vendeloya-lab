variable "subscription_id" {
  type        = string
  description = "Suscripción de Azure. No se despliega nada en el laboratorio académico."
  default     = "00000000-0000-0000-0000-000000000000"
}

variable "location" {
  type    = string
  default = "centralus"
}

variable "prefix" {
  type    = string
  default = "vendeloya"
}

variable "admin_group_object_id" {
  type        = string
  description = "Grupo de Microsoft Entra ID con rol de administrador del clúster."
  default     = "00000000-0000-0000-0000-000000000000"
}

variable "db_admin_password" {
  type        = string
  sensitive   = true
  description = "Se entrega por variable de entorno o Key Vault. Nunca se escribe en el repositorio."
}
