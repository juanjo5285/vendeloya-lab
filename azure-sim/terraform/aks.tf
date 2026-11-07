resource "azurerm_kubernetes_cluster" "aks" {
  #checkov:skip=CKV_AZURE_117:Se usan llaves administradas por Microsoft; el conjunto de cifrado con llave propia queda para producción si hay requisito de cumplimiento.
  name                      = "${var.prefix}-aks"
  location                  = azurerm_resource_group.rg.location
  resource_group_name       = azurerm_resource_group.rg.name
  dns_prefix                = "${var.prefix}-aks"
  sku_tier                  = "Standard"
  private_cluster_enabled   = true
  local_account_disabled    = true
  azure_policy_enabled      = true
  automatic_upgrade_channel = "patch"

  role_based_access_control_enabled = true

  azure_active_directory_role_based_access_control {
    azure_rbac_enabled     = true
    admin_group_object_ids = [var.admin_group_object_id]
  }

  default_node_pool {
    name                 = "system"
    vm_size              = "Standard_D2s_v5"
    node_count           = 2
    vnet_subnet_id       = azurerm_subnet.aks.id
    os_disk_type         = "Ephemeral"
    max_pods             = 50
    auto_scaling_enabled = false

    # Cifra discos temporales y cachés del nodo, y deja el grupo del sistema solo para pods críticos.
    host_encryption_enabled      = true
    only_critical_addons_enabled = true
    upgrade_settings {
      max_surge = "33%"
    }
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin = "azure"
    network_policy = "azure"
  }

  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id
  }

  key_vault_secrets_provider {
    secret_rotation_enabled = true
  }
}

# Grupo de nodos de usuario: aquí corren las cargas de la tienda, separadas del sistema.
resource "azurerm_kubernetes_cluster_node_pool" "user" {
  name                    = "user"
  kubernetes_cluster_id   = azurerm_kubernetes_cluster.aks.id
  vm_size                 = "Standard_D2s_v5"
  node_count              = 2
  mode                    = "User"
  vnet_subnet_id          = azurerm_subnet.aks.id
  os_disk_type            = "Ephemeral"
  max_pods                = 50
  host_encryption_enabled = true
}
