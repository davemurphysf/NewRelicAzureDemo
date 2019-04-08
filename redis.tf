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

resource "azurerm_network_interface" "redis-ext-nic" {
    name                = "${var.rg_prefix}-redis-ext-nic"
    location            = "${var.location}"
    resource_group_name = "${azurerm_resource_group.rg.name}"
    network_security_group_id = "${azurerm_network_security_group.redis-ext-nsg.id}"

    ip_configuration {
        name                          = "${var.rg_prefix}-redis-ext-ipconfig"
        subnet_id                     = "${azurerm_subnet.external-subnet.id}"
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id          = "${azurerm_public_ip.redis-pip.id}"
    }
}

data "template_file" "could-init-redis" {
    template = "${file("redis-cloud-config.sh")}"
    vars = {
        nr_key          = "${var.nr_license_key}"
        hostname        = "${var.hostname}"
        redis_config    = "${base64encode(file("redis-config.yml"))}"
    }
}

resource "azurerm_virtual_machine" "redis" {
    name                                = "${var.rg_prefix}-redis-vm"
    location                            = "${var.location}"
    resource_group_name                 = "${azurerm_resource_group.rg.name}"
    vm_size                             = "${var.vm_size}"
    primary_network_interface_id        = "${azurerm_network_interface.redis-ext-nic.id}"
    network_interface_ids               = ["${azurerm_network_interface.redis-ext-nic.id}","${azurerm_network_interface.redis-nic.id}"]
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
        managed_disk_type = "Premium_LRS"
        caching           = "ReadWrite"
        create_option     = "FromImage"
    }

    os_profile {
        computer_name   = "${var.hostname}-redis"
        admin_username  = "${var.admin_username}"
        custom_data     = "${data.template_file.could-init-redis.rendered}"
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
        host            = "${azurerm_public_ip.redis-pip.fqdn}"
        private_key     = "${file("~/.ssh/id_rsa")}"
        timeout         = "10m"
    }

    provisioner "remote-exec" {
        inline = [
            "cloud-init status --wait",
            "curl https://download.newrelic.com/infrastructure_agent/gpg/newrelic-infra.gpg | sudo apt-key add -",
            "sudo apt update",
            "sudo apt install redis newrelic-infra nri-redis -y",
            "sudo cp /etc/redis-config.yml /etc/newrelic-infra/integrations.d/redis-config.yml",
            "sudo sed -i 's/bind 127.0.0.1 ::1/bind 0.0.0.0 ::1/' /etc/redis/redis.conf",
            "sudo sed -i 's/protected-mode yes/protected-mode no/' /etc/redis/redis.conf",
            "sudo shutdown -r 1"
        ]
    }
}