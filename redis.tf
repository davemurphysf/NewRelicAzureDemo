resource "azurerm_network_interface" "redis-nic" {
    name                        = "${var.rg_prefix}-redis-nic"
    location                    = "${var.location}"
    resource_group_name         = "${azurerm_resource_group.rg.name}"
    network_security_group_id   = "${azurerm_network_security_group.redis-nsg.id}"

    ip_configuration {
        name                          = "${var.rg_prefix}-redis-ipconfig"
        subnet_id                     = "${azurerm_subnet.internal-subnet.id}"
        private_ip_address_allocation = "Dynamic"
    }
}

resource "azurerm_virtual_machine" "redis" {
    name                                = "${var.rg_prefix}-redis-vm"
    location                            = "${var.location}"
    resource_group_name                 = "${azurerm_resource_group.rg.name}"
    vm_size                             = "${var.vm_size}"
    primary_network_interface_id        = "${azurerm_network_interface.redis-nic.id}"
    network_interface_ids               = ["${azurerm_network_interface.redis-nic.id}"]
    depends_on                          = ["azurerm_virtual_machine.bastion"]
    delete_os_disk_on_termination       = true
    delete_data_disks_on_termination    = true
    tags                                = "${var.tags}"

    storage_image_reference {
        publisher = "${var.image_publisher}"
        offer     = "${var.image_offer}"
        sku       = "${var.image_sku}"
        version   = "${var.image_version}"
    }

    storage_os_disk {
        name              = "${var.hostname}-redis-osdisk"
        managed_disk_type = "Standard_LRS"
        caching           = "ReadWrite"
        create_option     = "FromImage"
    }

    os_profile {
        computer_name   = "${var.hostname}-redis"
        admin_username  = "${var.admin_username}"
    }

    os_profile_linux_config {
        disable_password_authentication = true

        ssh_keys {
            path     = "/home/${var.admin_username}/.ssh/authorized_keys"
            key_data = "${file("~/.ssh/id_rsa.pub")}"
        }
    }

    boot_diagnostics {
        enabled     = true
        storage_uri = "${azurerm_storage_account.stor.primary_blob_endpoint}"
    }

    connection {
        type            = "ssh"
        bastion_host    = "${azurerm_public_ip.bastion-pip.fqdn}"
        bastion_user    = "${var.admin_username}" 
        bastion_private_key = "${file("~/.ssh/id_rsa")}"
        user            = "${var.admin_username}"        
        host            = "${azurerm_network_interface.redis-nic.private_ip_address}"
        private_key     = "${file("~/.ssh/id_rsa")}"
        timeout         = "5m"
    }

    provisioner "remote-exec" {
        inline = [
            "printf \"license_key: ${var.nr_license_key}\" | sudo tee -a /etc/newrelic-infra.yml",
            "printf \"display_name: ${var.hostname}-redis\" | sudo tee -a /etc/newrelic-infra.yml",
            "curl https://download.newrelic.com/infrastructure_agent/gpg/newrelic-infra.gpg | sudo apt-key add -",
            "printf \"deb [arch=amd64] https://download.newrelic.com/infrastructure_agent/linux/apt bionic main\" | sudo tee -a /etc/apt/sources.list.d/newrelic-infra.list",
            "sudo apt-get update && sudo apt-get install newrelic-infra nri-redis redis -y",
            "printf \"${file("redis-config.yml")}\" | sudo tee -a /etc/newrelic-infra/integrations.d/redis-config.yml",
            "sudo systemctl start newrelic-infra"
        ]
    }
}