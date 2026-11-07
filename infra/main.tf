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
