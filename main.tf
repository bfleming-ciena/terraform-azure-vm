# This is copied from the azure module, but modified to allow data disk attachments and
# the ability to create multiple copies of that config.

provider "azurerm" {
 version = "~> 1.14"
}

provider "random" {
  version = "~> 1.0"
}

module "os" {
  source       = "./os"
  vm_os_simple = "${var.vm_os_simple}"
}

resource "random_id" "vm-sa" {
  keepers = {
    vm_hostname = "${var.vm_hostname}"
  }

  byte_length = 6
}

resource "azurerm_storage_account" "vm-sa" {
  count                    = "${var.boot_diagnostics == "true" ? 1 : 0}"
  name                     = "bootdiag${lower(random_id.vm-sa.hex)}"
  resource_group_name      = "${var.resource_group_name}"
  location                 = "${var.location}"
  account_tier             = "${element(split("_", var.boot_diagnostics_sa_type),0)}"
  account_replication_type = "${element(split("_", var.boot_diagnostics_sa_type),1)}"
  tags                     = "${var.tags}"
}

####################################################################################################
# MANAGED DISKS
#
resource "azurerm_managed_disk" "data_disks" {
  count                = "${length(var.data_disk_spec) * var.nb_instances}"
  name                 = "${var.vm_hostname}-disk${count.index}"
  location             = "${var.location}"
  resource_group_name  = "${var.resource_group_name}"
  storage_account_type = "${lookup(var.data_disk_spec[count.index % length(var.data_disk_spec)], "type")}"
  create_option        = "Empty"
  disk_size_gb         = "${lookup(var.data_disk_spec[count.index % length(var.data_disk_spec)], "size")}"
}

resource "azurerm_virtual_machine_data_disk_attachment" "disk_attachments" {
  count              = "${length(var.data_disk_spec) * var.nb_instances}"
  managed_disk_id    = "${element(azurerm_managed_disk.data_disks.*.id, count.index)}"                                                    #"${azurerm_managed_disk.test.id}"
  virtual_machine_id = "${element(azurerm_virtual_machine.vm-windows-with-datadisk.*.id, floor(count.index/length(var.data_disk_spec)))}"
  lun                = "${count.index % length(var.data_disk_spec)}"
  caching            = "${lookup(var.data_disk_spec[count.index % length(var.data_disk_spec)], "cache")}"
}

resource "azurerm_virtual_machine" "vm-windows-with-datadisk" {
  count                         = "${length(var.custom_hostnames) <= 0 ? var.nb_instances : 0}"
  name                          = "${var.nb_instances > 1 ? "${var.vm_hostname}-${count.index}" : var.vm_hostname }"
  location                      = "${var.location}"
  resource_group_name           = "${var.resource_group_name}"
  availability_set_id           = "${var.availability_set_id}"
  vm_size                       = "${var.vm_size}"
  network_interface_ids         = ["${element(azurerm_network_interface.vm.*.id, count.index)}"]
  delete_os_disk_on_termination = "${var.delete_os_disk_on_termination}"

  storage_image_reference {
    id        = "${var.vm_os_id}"
    publisher = "${var.vm_os_id == "" ? coalesce(var.vm_os_publisher, module.os.calculated_value_os_publisher) : ""}"
    offer     = "${var.vm_os_id == "" ? coalesce(var.vm_os_offer, module.os.calculated_value_os_offer) : ""}"
    sku       = "${var.vm_os_id == "" ? coalesce(var.vm_os_sku, module.os.calculated_value_os_sku) : ""}"
    version   = "${var.vm_os_id == "" ? var.vm_os_version : ""}"
  }

  storage_os_disk {
    name              = "${var.nb_instances > 1 ? "osdisk-${var.vm_hostname}-${count.index}" : "osdisk-${var.vm_hostname}" }"
    create_option     = "FromImage"
    caching           = "ReadWrite"
    managed_disk_type = "${var.storage_account_type}"
  }

  os_profile {
    computer_name  = "${var.nb_instances > 1 ? "${var.vm_hostname}${count.index}" : var.vm_hostname }"
    admin_username = "${var.admin_username}"
    admin_password = "${var.admin_password}"
  }

  tags = "${var.tags}"

  os_profile_windows_config {
    provision_vm_agent = "${var.provision_vm_agent}"
  }

  boot_diagnostics {
    enabled     = "${var.boot_diagnostics}"
    storage_uri = "${var.boot_diagnostics == "true" ? join(",", azurerm_storage_account.vm-sa.*.primary_blob_endpoint) : "" }"
  }
}

resource "azurerm_public_ip" "vm" {
  count                        = "${var.public_ip == "true" ? 1: 0}"
  name                         = "${var.vm_hostname}-publicIP"
  location                     = "${var.location}"
  resource_group_name          = "${var.resource_group_name}"          #"${azurerm_resource_group.vm.name}"
  public_ip_address_allocation = "${var.public_ip_address_allocation}"
  domain_name_label            = "${element(var.public_ip_dns, 0)}"
}

resource "azurerm_network_interface" "vm" {
  count               = "${var.nb_instances}"
  name                = "${var.nb_instances > 1 ? "nic-${var.vm_hostname}-${count.index}" : "nic-${var.vm_hostname}" }"
  location            = "${var.location}"
  resource_group_name = "${var.resource_group_name}"
  network_security_group_id = "${var.network_security_group_id}" #"${length(var.network_security_group_id)) > 0 var.network_security_group_id : ""}"

  ip_configuration {
    name                          = "ipconfig"
    subnet_id                     = "${var.vnet_subnet_id}"
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = "${length(azurerm_public_ip.vm.*.id) > 0 ? element(concat(azurerm_public_ip.vm.*.id, list("")), count.index) : ""}"
  }
}
