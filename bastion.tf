resource "azurerm_network_interface" "bastion-nic" {
    name                = "${var.rg_prefix}-bastion-nic"
    location            = "${var.location}"
    resource_group_name = "${azurerm_resource_group.rg.name}"

    ip_configuration {
        name                          = "${var.rg_prefix}-bastion-ipconfig"
        subnet_id                     = "${azurerm_subnet.internal-subnet.id}"
        private_ip_address_allocation = "Dynamic"
    }
}

resource "azurerm_network_interface" "bastion-ext-nic" {
    name                = "${var.rg_prefix}-bastion-ext-nic"
    location            = "${var.location}"
    resource_group_name = "${azurerm_resource_group.rg.name}"
    network_security_group_id = "${azurerm_network_security_group.bastion-ext-nsg.id}"

    ip_configuration {
        name                          = "${var.rg_prefix}-bastion-ext-ipconfig"
        subnet_id                     = "${azurerm_subnet.external-subnet.id}"
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id          = "${azurerm_public_ip.bastion-pip.id}"
    }
}

resource "azurerm_virtual_machine" "bastion" {
    name                                = "${var.rg_prefix}-bastion-vm"
    location                            = "${var.location}"
    resource_group_name                 = "${azurerm_resource_group.rg.name}"
    vm_size                             = "${var.vm_size}"
    primary_network_interface_id        = "${azurerm_network_interface.bastion-ext-nic.id}"
    network_interface_ids               = ["${azurerm_network_interface.bastion-nic.id}", "${azurerm_network_interface.bastion-ext-nic.id}"]
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
        name              = "${var.hostname}-bastion-osdisk"
        managed_disk_type = "Standard_LRS"
        caching           = "ReadWrite"
        create_option     = "FromImage"
    }

    os_profile {
        computer_name   = "${var.hostname}"
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
        user            = "${var.admin_username}"        
        host            = "${azurerm_public_ip.bastion-pip.fqdn}"
        private_key     = "${file("~/.ssh/id_rsa")}"
        timeout         = "5m"
    }

  tags = "${var.tags}"
}