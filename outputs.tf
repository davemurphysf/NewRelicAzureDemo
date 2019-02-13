output "bastion_ip_address" {
  value = "${azurerm_public_ip.bastion-pip.ip_address}"
}

output "app_ip_address" {
  value = "${azurerm_public_ip.app-pip.ip_address}"
}