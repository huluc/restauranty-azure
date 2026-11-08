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
