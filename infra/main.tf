locals {
  tags = {
    owner      = "hilal"
    project    = "restauranty"
    managed_by = "terraform"
  }
}

resource "azurerm_resource_group" "main" {
  name     = "rg-${var.prefix}"
  location = var.location
  tags     = local.tags
}

data "azurerm_client_config" "current" {}

module "log_analytics" {
  source              = "./modules/log_analytics"
  name                = "log-${var.prefix}"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.tags
}

module "acr" {
  source              = "./modules/acr"
  name                = "acr${replace(var.prefix, "-", "")}"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.tags
}

module "key_vault" {
  source              = "./modules/key_vault"
  name                = "kv-${var.prefix}"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.tags
  tenant_id           = data.azurerm_client_config.current.tenant_id
  admin_object_id     = data.azurerm_client_config.current.object_id
}

module "aks_prod" {
  count                       = var.aks_enabled ? 1 : 0
  source                      = "./modules/aks"
  name                        = "aks-${var.prefix}-prod"
  location                    = var.location
  resource_group_name         = azurerm_resource_group.main.name
  tags                        = merge(local.tags, { environment = "production" })
  log_analytics_workspace_id  = module.log_analytics.id
  acr_id                      = module.acr.id
  eso_identity_id             = azurerm_user_assigned_identity.eso.id
  system_vm_size              = "Standard_D2as_v7"
  system_only_critical_addons = true
  zones                       = ["1", "2", "3"]
  user_pool_enabled           = true
  user_vm_size                = "Standard_D2s_v6"
}

module "aks_staging" {
  count                      = var.aks_enabled ? 1 : 0
  source                     = "./modules/aks"
  name                       = "aks-${var.prefix}-staging"
  location                   = var.location
  resource_group_name        = azurerm_resource_group.main.name
  tags                       = merge(local.tags, { environment = "staging" })
  log_analytics_workspace_id = module.log_analytics.id
  acr_id                     = module.acr.id
  eso_identity_id            = azurerm_user_assigned_identity.eso.id
  system_vm_size             = "Standard_D2s_v7"
}

# Identity used by External Secrets Operator in both clusters (workload identity)
resource "azurerm_user_assigned_identity" "eso" {
  name                = "id-${var.prefix}-eso"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.tags
}

resource "azurerm_role_assignment" "eso_kv_read" {
  scope                = module.key_vault.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.eso.principal_id
}
