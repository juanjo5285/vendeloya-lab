resource "azurerm_private_dns_zone" "mysql" {
  name                = "${var.prefix}.private.mysql.database.azure.com"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "mysql" {
  name                  = "${var.prefix}-mysql-link"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.mysql.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
}

resource "azurerm_mysql_flexible_server" "db" {
  #checkov:skip=CKV_AZURE_53:El servidor usa integración con la red virtual (subred delegada) y no tiene punto de conexión público.
  #checkov:skip=CKV2_AZURE_56:MySQL flexible se aísla con subred delegada y DNS privado; no usa Private Endpoint por diseño del servicio.
  name                         = "${var.prefix}-mysql"
  location                     = azurerm_resource_group.rg.location
  resource_group_name          = azurerm_resource_group.rg.name
  administrator_login          = "vendeloya_admin"
  administrator_password       = var.db_admin_password
  version                      = "8.0.21"
  sku_name                     = "GP_Standard_D2ds_v4"
  delegated_subnet_id          = azurerm_subnet.db.id
  private_dns_zone_id          = azurerm_private_dns_zone.mysql.id
  backup_retention_days        = 14
  geo_redundant_backup_enabled = true

  storage {
    auto_grow_enabled = true
  }

  depends_on = [azurerm_private_dns_zone_virtual_network_link.mysql]
}

resource "azurerm_mysql_flexible_server_configuration" "tls" {
  name                = "require_secure_transport"
  resource_group_name = azurerm_resource_group.rg.name
  server_name         = azurerm_mysql_flexible_server.db.name
  value               = "ON"
}

resource "azurerm_mysql_flexible_server_configuration" "tls_version" {
  name                = "tls_version"
  resource_group_name = azurerm_resource_group.rg.name
  server_name         = azurerm_mysql_flexible_server.db.name
  value               = "TLSv1.2"
}

resource "azurerm_storage_account" "backups" {
  #checkov:skip=CKV_AZURE_33:La cuenta se usa solo para blobs de respaldo; no se usa el servicio de colas.
  #checkov:skip=CKV2_AZURE_1:Se usan llaves administradas por Microsoft; la llave propia queda para producción si hay requisito de cumplimiento.
  name                            = "${var.prefix}backup001"
  location                        = azurerm_resource_group.rg.location
  resource_group_name             = azurerm_resource_group.rg.name
  account_tier                    = "Standard"
  account_replication_type        = "GRS"
  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  allow_nested_items_to_be_public = false
  public_network_access_enabled   = false
  shared_access_key_enabled       = false

  blob_properties {
    versioning_enabled = true
    delete_retention_policy {
      days = 30
    }
  }

  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
  }
}

resource "azurerm_private_endpoint" "backups" {
  name                = "${var.prefix}-backups-pe"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.pe.id

  private_service_connection {
    name                           = "backups"
    private_connection_resource_id = azurerm_storage_account.backups.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }
}
