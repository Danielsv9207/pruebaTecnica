terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = ">= 2.56"
    }
  }

  required_version = ">= 0.14.9"
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = "rg-daniel-velasquez"
  location = "West Europe"
}

resource "azurerm_storage_account" "storage-account" {
  name                     = "inputfiledanielvelasquez"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = "West Europe"
  account_tier             = "Standard"
  account_replication_type = "GRS"

  tags = {
    environment = "pruebaTecnica"
  }
}