resource "azurerm_network_interface" "db-nic" {
    name                        = "${var.rg_prefix}-db-nic"
    location                    = "${var.location}"
    resource_group_name         = "${azurerm_resource_group.rg.name}"
    network_security_group_id   = "${azurerm_network_security_group.db-nsg.id}"

    ip_configuration {
        name                          = "${var.rg_prefix}-db-ipconfig"
        subnet_id                     = "${azurerm_subnet.internal-subnet.id}"
        private_ip_address_allocation = "Dynamic"
    }
}

data "template_file" "nr_pg_config" {
    template = "${file("pg-config.yml")}"
    vars = {
        username = "${var.pg_nr_username}"
        password = "${var.pg_nr_password}"
    }
}

data "template_file" "pg_init" {
    template = "${file("pg-init.sql")}"
    vars = {
        username = "${var.pg_nr_username}"
        password = "${var.pg_nr_password}"
    }
}

resource "azurerm_virtual_machine" "db" {
    name                                = "${var.rg_prefix}-db-vm"
    location                            = "${var.location}"
    resource_group_name                 = "${azurerm_resource_group.rg.name}"
    vm_size                             = "${var.vm_size}"
    primary_network_interface_id        = "${azurerm_network_interface.db-nic.id}"
    network_interface_ids               = ["${azurerm_network_interface.db-nic.id}"]
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
        name              = "${var.hostname}-db-osdisk"
        managed_disk_type = "Standard_LRS"
        caching           = "ReadWrite"
        create_option     = "FromImage"
    }

    os_profile {
        computer_name   = "${var.hostname}-db"
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
        host            = "${azurerm_network_interface.db-nic.private_ip_address}"
        private_key     = "${file("~/.ssh/id_rsa")}"
        timeout         = "5m"
    }

    provisioner "remote-exec" {
        inline = [
            "printf \"license_key: ${var.nr_license_key}\" | sudo tee -a /etc/newrelic-infra.yml",
            "curl https://download.newrelic.com/infrastructure_agent/gpg/newrelic-infra.gpg | sudo apt-key add -",
            "printf \"deb [arch=amd64] https://download.newrelic.com/infrastructure_agent/linux/apt xenial main\" | sudo tee -a /etc/apt/sources.list.d/newrelic-infra.list",
            "sudo apt-get update && sudo apt-get install newrelic-infra nri-postgresql postgresql postgresql-contrib -y",
            "sudo wget https://cdn.patricktriest.com/atlas-of-thrones/atlas_of_thrones.sql",
            "sudo -i -u postgres psql -a -f /tmp/pg-init.sql",
            "sudo -u postgres psql -a atlas_of_thrones < atlas_of_thrones.sql",
            "printf \"${data.template_file.pg_init.rendered}\" | sudo tee -a /etc/newrelic-infra/integrations.d/postgresql-config.yml",
            "sudo systemctl restart newrelic-infra"
        ]
    }
}