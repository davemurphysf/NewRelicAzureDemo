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

resource "azurerm_network_interface" "db-ext-nic" {
    name                        = "${var.rg_prefix}-db-ext-nic"
    location                    = "${var.location}"
    resource_group_name         = "${azurerm_resource_group.rg.name}"
    network_security_group_id   = "${azurerm_network_security_group.db-ext-nsg.id}"

    ip_configuration {
        name                          = "${var.rg_prefix}-db-ext-ipconfig"
        subnet_id                     = "${azurerm_subnet.external-subnet.id}"
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id          = "${azurerm_public_ip.db-pip.id}" 
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
        nr_username = "${var.pg_nr_username}"
        nr_password = "${var.pg_nr_password}"
        username = "${var.pg_username}"
        password = "${var.pg_password}"
    }
}

data "template_file" "pg_permissions" {
    template = "${file("pg-permissions.sql")}"
    vars = {
        nr_username = "${var.pg_nr_username}"
        username = "${var.pg_username}"
    }
}

data "template_file" "pg_hba" {
    template = "${file("pg_hba.conf")}"
    vars = {
        internal_subnet = "${var.internal_subnet_prefix}"
    }
}

resource "azurerm_virtual_machine" "db" {
    name                                = "${var.rg_prefix}-db-vm"
    location                            = "${var.location}"
    resource_group_name                 = "${azurerm_resource_group.rg.name}"
    vm_size                             = "${var.vm_size}"
    primary_network_interface_id        = "${azurerm_network_interface.db-ext-nic.id}"
    network_interface_ids               = ["${azurerm_network_interface.db-ext-nic.id}", "${azurerm_network_interface.db-nic.id}"]
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
        managed_disk_type = "Premium_LRS"
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
        host            = "${azurerm_public_ip.db-pip.fqdn}"
        private_key     = "${file("~/.ssh/id_rsa")}"
        timeout         = "5m"
    }

    provisioner "file" {
        source      = "atlas_of_thrones.sql"
        destination = "/tmp/atlas_of_thrones.sql"
    }

    provisioner "file" {
        content = "${data.template_file.nr_pg_config.rendered}"
        destination = "/tmp/postgresql-config.yml"
    }

    provisioner "file" {
        content = "${data.template_file.pg_init.rendered}"
        destination = "/tmp/pg-init.sql"
    }

    provisioner "file" {
        content = "${data.template_file.pg_hba.rendered}"
        destination = "/tmp/pg_hba.conf"
    }

    provisioner "file" {
        source      = "postgresql.conf"
        destination = "/tmp/postgresql.conf"
    }

    provisioner "file" {
        content = "${data.template_file.pg_permissions.rendered}"
        destination = "/tmp/pg-permissions.sql"
    }

    provisioner "remote-exec" {
        inline = [
            "printf \"license_key: ${var.nr_license_key}\n\" | sudo tee -a /etc/newrelic-infra.yml",
            "printf \"display_name: ${var.hostname}-db\n\" | sudo tee -a /etc/newrelic-infra.yml",
            "curl https://download.newrelic.com/infrastructure_agent/gpg/newrelic-infra.gpg | sudo apt-key add -",
            "printf \"deb [arch=amd64] https://download.newrelic.com/infrastructure_agent/linux/apt bionic main\" | sudo tee -a /etc/apt/sources.list.d/newrelic-infra.list",
            "sudo apt update",
            "sudo apt install newrelic-infra nri-postgresql postgresql-10 postgresql-contrib postgis -y",
            "sudo cp /tmp/postgresql-config.yml /etc/newrelic-infra/integrations.d/postgresql-config.yml",
            "sudo chmod +r /tmp/pg-init.sql",
            "sudo -u postgres psql -a -f /tmp/pg-init.sql",
            "echo \"After sql init\" ",
            "sudo chmod +r /tmp/atlas_of_thrones.sql",
            "sudo -u postgres psql -a atlas_of_thrones < /tmp/atlas_of_thrones.sql",
            "echo \"After sql dump restore\" ",
            "sudo -u postgres psql -a atlas_of_thrones < /tmp/pg-permissions.sql",
            "echo \"After sql permissions\" ",
            "sudo cp /tmp/pg_hba.conf /etc/postgresql/10/main/pg_hba.conf",
            "echo \"After hba\" ",
            "sudo chown postgres:postgres /etc/postgresql/10/main/pg_hba.conf",
            "sudo cp /tmp/postgresql.conf /etc/postgresql/10/main/postgresql.conf",
            "sudo chown postgres:postgres /etc/postgresql/10/main/postgresql.conf",
            "sudo systemctl restart postgresql",
            "sudo systemctl start newrelic-infra",
            "sudo shutdown -r 1"
        ]
    }
}