terraform {
  required_version = ">= 1.16"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }

  backend "azurerm" {
    resource_group_name  = "rg-hilal-tfstate"
    storage_account_name = "sthilaltf20614"
    container_name       = "tfstate"
    key                  = "restauranty.tfstate"
    use_azuread_auth     = true
  }
}
