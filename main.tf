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

#Declaracion del Grupo de Recursos
resource "azurerm_resource_group" "rg" {
  name     = "rg-daniel-velasquez"
  location = "West Europe"
}

#Declaracion de Storages definidos en la arquitectra
resource "azurerm_storage_account" "storageaccount1" {
  name                     = "inputfiledanielvelasquez"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "GRS"

  tags = {
    environment = "pruebaTecnica"
  }
}

resource "azurerm_storage_account" "storageaccount2" {
  name                     = "outfiledanielvelasquez"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "GRS"

  tags = {
    environment = "pruebaTecnica"
  }
}

resource "azurerm_storage_container" "oucontainerblob" {
  name                  = "outputblob"
  storage_account_name  = azurerm_storage_account.storageaccount2.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "incontainerblob" {
  name                  = "inputblob"
  storage_account_name  = azurerm_storage_account.storageaccount1.name
  container_access_type = "private"
}

#Generacion del Token SAS para la conexion al Storage de Input1
data "azurerm_storage_account_sas" "sastokensa" {
  connection_string = azurerm_storage_account.storageaccount1.primary_connection_string
  https_only        = true
  signed_version    = "2017-07-29"

  resource_types {
    service   = true
    container = false
    object    = false
  }

  services {
    blob  = true
    queue = false
    table = false
    file  = true
  }

  start  = "2021-04-20T00:00:00Z"
  expiry = "2022-04-21T00:00:00Z"

  permissions {
    read    = true
    write   = true
    delete  = false
    list    = false
    add     = true
    create  = true
    update  = false
    process = false
  }
}

#Declaracion de la Red provada Virtual para el container Instance
resource "azurerm_virtual_network" "virtualnetwork" {
  name                = "virtnetname"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "privatesn" {
  name                 = "privatesubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.virtualnetwork.name
  address_prefixes     = ["10.0.2.0/24"]

  delegation {
    name = "delegation"

    service_delegation {
      name    = "Microsoft.ContainerInstance/containerGroups"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

#Declaracion del Security Group que tendra la Subnet
resource "azurerm_network_security_group" "nsg" {
  name                = "SecurityGroup1"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "backendport"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "10.0.2.0/24"
    destination_address_prefix = "*"
  }

  tags = {
    environment = "pruebaTecnica"
    }
  }

  # Event Grid y Cola para el disparador de la Funcion
resource "azurerm_storage_queue" "inputqueue" {
  name                 = "storagequeue"
  storage_account_name = azurerm_storage_account.storageaccount1.name
}

resource "azurerm_eventgrid_event_subscription" "inputevent" {
  name  = "EventSubscription"
  scope = azurerm_storage_account.storageaccount1.id
  included_event_types = [ "Microsoft.Storage.BlobCreated" ]

  storage_queue_endpoint {
    storage_account_id = azurerm_storage_account.storageaccount1.id
    queue_name         = azurerm_storage_queue.inputqueue.name
  }
 
}

resource "azurerm_app_service_plan" "serviceplan" {
  name                = "azure-function-service-plan"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  kind                = "FunctionApp"

  sku {
    tier = "Dynamic"
    size = "Y1"
  }
}

resource "azurerm_function_app" "function" {
  name                       = "etl-functions-danielvelasquez"
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  app_service_plan_id        = azurerm_app_service_plan.serviceplan.id
  storage_account_name       = azurerm_storage_account.storageaccount2.name
  storage_account_access_key = azurerm_storage_account.storageaccount2.primary_access_key
}

#Despliegue de Backend
resource "azurerm_container_group" "containerintence" {
  name                = "continstance"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  ip_address_type     = "private"
  os_type             = "Linux"
  network_profile_id  = azurerm_network_profile.netprof.id

  container {
    name   = "backend-container"
    image  = "microsoft/aci-helloworld:latest"
    cpu    = "0.5"
    memory = "1.5"

    ports {
      port     = 443
      protocol = "TCP"
    }
  }

  tags = {
    environment = "pruebaTecnica"
  }
}

resource "azurerm_network_profile" "netprof" {
  name                = "netprofile"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  container_network_interface {
    name = "cnic"

    ip_configuration {
      name      = "ipconfig"
      subnet_id = azurerm_subnet.privatesn.id
    }
  }
}

#resource "azurerm_app_service_certificate" "httpscert" {
#  name                = "frontcert"
#  resource_group_name = azurerm_resource_group.rg.name
#  location            = azurerm_resource_group.rg.location
#  pfx_blob            = filebase64("certificate.pfx")
#  password            = "terraform"
#}