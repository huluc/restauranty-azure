resource "azurerm_kubernetes_cluster" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = var.name
  sku_tier            = "Free"
  tags                = var.tags

  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  default_node_pool {
    name                         = "system"
    vm_size                      = var.system_vm_size
    node_count                   = var.system_node_count
    zones                        = var.zones
    os_disk_size_gb              = 64
    only_critical_addons_enabled = var.system_only_critical_addons
    temporary_name_for_rotation  = "systemtmp"

    upgrade_settings {
      max_surge = "10%"
    }
    tags = var.tags
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_data_plane  = "cilium"
    network_policy      = "cilium"
    load_balancer_sku   = "standard"
  }

  oms_agent {
    log_analytics_workspace_id      = var.log_analytics_workspace_id
    msi_auth_for_monitoring_enabled = true
  }
}

resource "azurerm_kubernetes_cluster_node_pool" "user" {
  count                 = var.user_pool_enabled ? 1 : 0
  name                  = "user"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.this.id
  mode                  = "User"
  vm_size               = var.user_vm_size
  zones                 = var.zones
  os_disk_size_gb       = 64
  auto_scaling_enabled  = true
  min_count             = var.user_min_count
  max_count             = var.user_max_count

  upgrade_settings {
    max_surge = "10%"
  }
  tags = var.tags
}

resource "azurerm_role_assignment" "acr_pull" {
  scope                = var.acr_id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.this.kubelet_identity[0].object_id
}

resource "azurerm_federated_identity_credential" "eso" {
  name      = "fic-${var.name}-eso"
  parent_id = var.eso_identity_id
  audience  = ["api://AzureADTokenExchange"]
  issuer    = azurerm_kubernetes_cluster.this.oidc_issuer_url
  subject   = "system:serviceaccount:external-secrets:external-secrets"
}

# Container Insights needs a data collection rule when the agent uses managed identity.
# The portal creates it automatically; Terraform does not.
resource "azurerm_monitor_data_collection_rule" "container_insights" {
  name                = "dcr-${var.name}-ci"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

  destinations {
    log_analytics {
      workspace_resource_id = var.log_analytics_workspace_id
      name                  = "ciworkspace"
    }
  }

  data_flow {
    streams      = ["Microsoft-ContainerInsights-Group-Default"]
    destinations = ["ciworkspace"]
  }

  data_sources {
    extension {
      name           = "ContainerInsightsExtension"
      extension_name = "ContainerInsights"
      streams        = ["Microsoft-ContainerInsights-Group-Default"]
      extension_json = jsonencode({
        dataCollectionSettings = {
          interval               = "1m"
          namespaceFilteringMode = "Off"
          enableContainerLogV2   = true
        }
      })
    }
  }
}

resource "azurerm_monitor_data_collection_rule_association" "container_insights" {
  name                    = "ContainerInsightsExtension"
  target_resource_id      = azurerm_kubernetes_cluster.this.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.container_insights.id
}
