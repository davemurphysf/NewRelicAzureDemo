variable "subscription_id" {
  description = "Azure subscription id; use `az account show`"
}

variable "tenant_id" {
  description = "Azure tennant id; use (az account show)"
}

variable "nr_license_key" {
  description = "New Relic License Key; more info: https://docs.newrelic.com/docs/accounts/install-new-relic/account-setup/license-key"
}
variable "resource_group" {
  description = "The name of the resource group in which to create the virtual network."
  default     = "nr-got-az-rg"
}

variable "rg_prefix" {
  description = "The shortened abbreviation to represent your resource group that will go on the front of some resources."
  default     = "nr-rg"
}

variable "hostname" {
  description = "VM name referenced also in storage-related names."
  default     = "nr-host"
}

variable "dns_name" {
  description = "Label for the Domain Name. Will be used to make up the FQDN. If a domain name label is specified, an A DNS record is created for the public IP in the Microsoft Azure DNS system."
  default     = "nr-got-az"
}

variable "location" {
  description = "The location/region where the virtual network is created. Changing this forces a new resource to be created."
  default     = "westus"
}

variable "virtual_network_name" {
  description = "The name for the virtual network."
  default     = "vnet"
}

variable "address_space" {
  description = "The address space that is used by the virtual network. You can supply more than one address space. Changing this forces a new resource to be created."
  default     = "10.0.0.0/16"
}

variable "internal_subnet_prefix" {
  description = "The address prefix to use for the subnet."
  default     = "10.0.1.0/24"
}

variable "external_subnet_prefix" {
  description = "The address prefix to use for the subnet."
  default     = "10.0.2.0/24"
}

variable "storage_account_tier" {
  description = "Defines the Tier of storage account to be created. Valid options are Standard and Premium."
  default     = "Standard"
}

variable "storage_replication_type" {
  description = "Defines the Replication Type to use for this storage account. Valid options include LRS, GRS etc."
  default     = "LRS"
}

variable "vm_size" {
  description = "Specifies the size of the virtual machine."
  default     = "Standard_B2ms"
}

variable "image_publisher" {
  description = "name of the publisher of the image (az vm image list)"
  default     = "Canonical"
}

variable "image_offer" {
  description = "the name of the offer (az vm image list)"
  default     = "UbuntuServer"
}

variable "image_sku" {
  description = "image sku to apply (az vm image list)"
  default     = "18.04-LTS"
}

variable "image_version" {
  description = "version of the image to apply (az vm image list)"
  default     = "latest"
}

variable "admin_username" {
  description = "administrator user name"
  default     = "myadmin"
}

variable "tags" {
  type        = "map"
  default     = {}
  description = "Any tags which should be assigned to the resources in this example"
}

variable "pg_username" {
  description = "Postgres username for the application"
  default     = "app_pg_username"
}

variable "pg_password" {
  description = "Postgres password for the application"
  default     = "ThisIsAVeryLongPasswordAndIsVerySecure"
}

variable "pg_nr_username" {
  description = "Postgres username for the New Relic"
  default     = "nr_pg_username"
}

variable "pg_nr_password" {
  description = "Postgres password for the New Relic"
  default     = "ThisIsAlsoAVeryLongPasswordAndIsVerySecure"
}
