output "ip_address" {
  value = "${azurerm_public_ip.app-pip.ip_address}"
}
