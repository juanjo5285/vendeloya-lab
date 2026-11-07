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
