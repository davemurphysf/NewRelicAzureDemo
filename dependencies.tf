provider "azurerm" {
  # More information on the authentication methods supported by
  # the AzureRM Provider can be found here:
  # http://terraform.io/docs/providers/azurerm/index.html
  
  subscription_id = "${var.subscription_id}"
  #client_id       = "${var.client_id}"
  #client_secret   = "${var.client_secret}"
  tenant_id       = "${var.tenant_id}"
  version           = "=1.21.0"
}

resource "azurerm_resource_group" "rg" {
  name     = "${var.resource_group}"
  location = "${var.location}"
  tags     = "${var.tags}"
}

resource "azurerm_virtual_network" "vnet" {
  name                = "${var.virtual_network_name}"
  location            = "${var.location}"
  address_space       = ["${var.address_space}"]
  resource_group_name = "${azurerm_resource_group.rg.name}"
  tags                = "${var.tags}"
}

resource "azurerm_subnet" "internal-subnet" {
  name                 = "${var.rg_prefix}-internal-subnet"
  virtual_network_name = "${azurerm_virtual_network.vnet.name}"
  resource_group_name  = "${azurerm_resource_group.rg.name}"
  address_prefix       = "${var.internal_subnet_prefix}"
}

resource "azurerm_subnet" "external-subnet" {
  name                 = "${var.rg_prefix}-external-subnet"
  virtual_network_name = "${azurerm_virtual_network.vnet.name}"
  resource_group_name  = "${azurerm_resource_group.rg.name}"
  address_prefix       = "${var.external_subnet_prefix}"
}

resource "azurerm_public_ip" "app-pip" {
  name                         = "${var.rg_prefix}-app-ip"
  location                     = "${var.location}"
  resource_group_name          = "${azurerm_resource_group.rg.name}"
  allocation_method            = "Dynamic"
  domain_name_label            = "${var.dns_name}-app"
  tags                         = "${var.tags}"
}

resource "azurerm_public_ip" "db-pip" {
  name                         = "${var.rg_prefix}-db-ip"
  location                     = "${var.location}"
  resource_group_name          = "${azurerm_resource_group.rg.name}"
  allocation_method            = "Dynamic"
  domain_name_label            = "${var.dns_name}-db"
  tags                         = "${var.tags}"
}

resource "azurerm_network_security_group" "app-ext-nsg" {
  name                = "${var.rg_prefix}-app-ext-nsg"
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.rg.name}"

  security_rule {
    name                       = "allow_HTTP"
    description                = "Allow HTTP access"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_security_group" "db-ext-nsg" {
  name                = "${var.rg_prefix}-db-ext-nsg"
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.rg.name}"

  security_rule {
    name                       = "allow_SSH"    
    description                = "Allow SSH access"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_security_group" "db-nsg" {
  name                = "${var.rg_prefix}-db-nsg"
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.rg.name}"

  security_rule {
    name                       = "allow_SSH"    
    description                = "Allow SSH access"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "${var.internal_subnet_prefix}"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow_Postgres"    
    description                = "Allow Postgres access"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5432"
    source_address_prefix      = "${var.internal_subnet_prefix}"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_security_group" "redis-nsg" {
  name                = "${var.rg_prefix}-redis-nsg"
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.rg.name}"

  security_rule {
    name                       = "allow_SSH"    
    description                = "Allow SSH access"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "${var.internal_subnet_prefix}"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow_Redis"    
    description                = "Allow Redis access"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "6379"
    source_address_prefix      = "${var.internal_subnet_prefix}"
    destination_address_prefix = "*"
  }
}

resource "azurerm_storage_account" "stor" {
  name                     = "nrgotazstore"
  location                 = "${var.location}"
  resource_group_name      = "${azurerm_resource_group.rg.name}"
  account_tier             = "${var.storage_account_tier}"
  account_replication_type = "${var.storage_replication_type}"
}
