resource "azurerm_network_interface" "app-nic" {
    name                = "${var.rg_prefix}-app-nic"
    location            = "${var.location}"
    resource_group_name = "${azurerm_resource_group.rg.name}"
    network_security_group_id = "${azurerm_network_security_group.app-nsg.id}"

    ip_configuration {
        name                          = "${var.rg_prefix}-app-ipconfig"
        subnet_id                     = "${azurerm_subnet.internal-subnet.id}"
        private_ip_address_allocation = "Dynamic"
    }
}

resource "azurerm_network_interface" "app-ext-nic" {
    name                = "${var.rg_prefix}-app-ext-nic"
    location            = "${var.location}"
    resource_group_name = "${azurerm_resource_group.rg.name}"
    network_security_group_id = "${azurerm_network_security_group.app-ext-nsg.id}"

    ip_configuration {
        name                          = "${var.rg_prefix}-app-ext-ipconfig"
        subnet_id                     = "${azurerm_subnet.external-subnet.id}"
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id          = "${azurerm_public_ip.app-pip.id}"
    }
}

data "template_file" "pm2-config" {
    template = "${file("app-pm2.json")}"
    vars = {
        postgres_user   = "${var.pg_username}"
        postgres_host   = "${azurerm_network_interface.db-nic.private_ip_address}"
        postgres_pw     = "${var.pg_password}"
        redis_host      = "${azurerm_network_interface.redis-nic.private_ip_address}"
    }
}
data "template_file" "could-init-app" {
    template = "${file("app-cloud-config.sh")}"
    vars = {
        pm2_config      = "${base64encode(data.template_file.pm2-config.rendered)}"
        nr_key          = "${var.nr_license_key}"
        hostname        = "${var.hostname}"
        ssh_key         = "${file("~/.ssh/id_rsa.pub")}"
        fqdn            = "${azurerm_public_ip.app-pip.fqdn}"
    }
}
resource "azurerm_virtual_machine" "app" {
    name                                = "${var.rg_prefix}-app-vm"
    location                            = "${var.location}"
    resource_group_name                 = "${azurerm_resource_group.rg.name}"
    vm_size                             = "${var.vm_size}"
    primary_network_interface_id        = "${azurerm_network_interface.app-ext-nic.id}"
    network_interface_ids               = ["${azurerm_network_interface.app-nic.id}", "${azurerm_network_interface.app-ext-nic.id}"]
    depends_on                          = ["azurerm_virtual_machine.redis", "azurerm_virtual_machine.db"]
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
        name              = "${var.hostname}-app-osdisk"
        managed_disk_type = "Premium_LRS"
        caching           = "ReadWrite"
        create_option     = "FromImage"
    }

    os_profile {
        computer_name   = "${var.hostname}"
        admin_username  = "${var.admin_username}"
        custom_data     = "${data.template_file.could-init-app.rendered}"
    }

    os_profile_linux_config {
        disable_password_authentication = true

        ssh_keys = [{
            path     = "/home/${var.admin_username}/.ssh/authorized_keys"
            key_data = "${file("~/.ssh/id_rsa.pub")}"
        }]
    }

    boot_diagnostics {
        enabled     = true
        storage_uri = "${azurerm_storage_account.stor.primary_blob_endpoint}"
    }

    connection {
        type            = "ssh"
        user            = "${var.admin_username}"        
        host            = "${azurerm_public_ip.app-pip.fqdn}"
        private_key     = "${file("~/.ssh/id_rsa")}"
        timeout         = "5m"
    }

    provisioner "file" {
        source      = "nginx.conf"
        destination = "~/nginx.conf"
    }

    provisioner "remote-exec" {
        inline = [
            "cloud-init status --wait > /dev/null 2>&1",
            "curl https://download.newrelic.com/infrastructure_agent/gpg/newrelic-infra.gpg | sudo apt-key add -",
            "curl -sL https://deb.nodesource.com/setup_10.x | sudo -E bash -",
            "sudo apt update",
            "sudo apt install gcc g++ make nginx newrelic-infra nodejs -y",
            "sudo cp nginx.conf /etc/nginx/nginx.conf",            
            "git clone https://github.com/davemurphysf/Atlas-Of-Thrones.git ~/app",
            "sed -i 's#https://api.atlasofthrones.com/#http://${azurerm_public_ip.app-pip.fqdn}:5000/#' ~/app/package.json",
            "(cd ~/app && npm i)",
            "(cd ~/app && npm run build)",
            "sudo mkdir -p /app/aot",
            "sudo chmod +t /app/aot",
            "sudo chmod -R 0777 /app/aot",            
            "sudo mv ~/app/* /app/aot",
            "sudo chown app:app -R /app/aot",
            "sudo npm i -g pm2",
            "sudo mkdir -p /var/log/pm2",
            "sudo chown app:app /var/log/pm2",
            "sudo -u app PM2_HOME='/app/aot/.pm2' pm2 start /etc/pm2_config.json --env production",
            "sudo env PM2_HOME='/app/aot' PATH=$PATH:/usr/bin /usr/lib/node_modules/pm2/bin/pm2 startup systemd -u app --hp /app/aot",
            "sudo -u app PM2_HOME='/app/aot/.pm2' pm2 save",
            "sudo shutdown -r 1"
        ]
    }
}