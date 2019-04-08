output "app_ip_address" {
  value = "${azurerm_public_ip.app-pip.ip_address}"
}

output "app_dns" {
  value = "${azurerm_public_ip.app-pip.fqdn}"
}
