
# Example usage:

########################################################################
# Resource Groups
#
# This is the top level. Manage it separately.
resource "azurerm_resource_group" "example" {
  name     = "example"
  location = "eastus"
}

resource "azurerm_availability_set" "example_aset" {
  name                = "example_aset"
  location            = "eastus"
  resource_group_name = "${azurerm_resource_group.example.name}"
  managed             = true
}

########################################################################
# Subnets
#
resource "azurerm_subnet" "example-subnet" {
  name                 = "example-subnet"
  virtual_network_name = "${azurerm_virtual_network.example-vnet.name}"
  resource_group_name  = "${azurerm_resource_group.example.name}"
  address_prefix       = "10.0.0.0/21"
  service_endpoints = ["Microsoft.Storage", "Microsoft.Sql"]
}

#########################################################################
# Networks
#
resource "azurerm_virtual_network" "example-vnet" {
  name                = "example-vnet"
  location            = "eastus"
  address_space       = ["10.0.0.0/21"]
  resource_group_name = "${azurerm_resource_group.example.name}"
}

####################################################################################################
# COMPUTE
#
# 
module "example_vm" {
  source              = "git@github.com:stonefury/terraform-azure-vm.git//"
  vm_size             = "Standard_E32-16s_v3"
  resource_group_name = "${azurerm_resource_group.example.name}"
  location            = "eastus"
  vm_hostname         = "examplevm"
  admin_password      = "adminfree123@"
  vm_os_simple        = "WindowsServer"

  vnet_subnet_id       = "${azurerm_subnet.example-subnet.id}"
  remote_port          = "3389"
  # public_ip            = "true"
  # public_ip_dns        = ["azw1wsqldw"]
  storage_account_type = "Standard_LRS"
  availability_set_id = "${azurerm_availability_set.example_aset.id}"

  data_disk_spec = [
    {
      size = "1024"

      type = "Premium_LRS"

      cache = "ReadOnly"
    },
    {
      size = "2048" #qty-1 -- P30 disk (1TB)

      type = "Premium_LRS"

      cache = "ReadOnly"
    },
    {
      size = "4095" # qty-1 -- P40 disk (2TB)

      type = "Premium_LRS"

      cache = "ReadOnly"
    },
    {
      size = "4095" # qty-3 -- P50 disk (4TB)

      type = "Premium_LRS"

      cache = "ReadOnly"
    },
    {
      size = "4095"

      type = "Premium_LRS"

      cache = "ReadOnly"
    },
    {
      size = "4095"

      type = "Standard_LRS"

      cache = "ReadOnly"
    },
    {
      size = "4095" # qty-3 -- S50 disk (4TB)

      type = "Standard_LRS"

      cache = "ReadOnly"
    },
    {
      size = "4095"

      type = "Standard_LRS"

      cache = "ReadOnly"
    },
  ]

  vm_os_publisher               = "MicrosoftSQLServer"
  vm_os_offer                   = "SQL2016SP2-WS2016-BYOL"
  vm_os_sku                     = "Enterprise"
  vm_os_version                 = "13.1.900310"
  delete_os_disk_on_termination = "true"
}

resource "azurerm_virtual_machine_extension" "example_sql_extension" {
  # depends_on           = ["module.example_vm"]
  name                 = "SqlIaasExtension"
  location             = "eastus"
  resource_group_name  = "${azurerm_resource_group.example.name}"
  virtual_machine_name = "${module.example_vm.vm_hostname[0]}"
  publisher            = "Microsoft.SqlServer.Management"
  type                 = "SqlIaaSAgent"
  type_handler_version = "1.2"

  settings = <<SETTINGS
      {
        "AutoTelemetrySettings": {
          "Region": "eastus"
        },
        "AutoPatchingSettings": {
          "PatchCategory": "WindowsMandatoryUpdates",
          "Enable": true,
          "DayOfWeek": "Sunday",
          "MaintenanceWindowStartingHour": "2",
          "MaintenanceWindowDuration": "60"
        },
        "KeyVaultCredentialSettings": {
          "Enable": false,
          "CredentialName": ""
        },
        "ServerConfigurationsManagementSettings": {
          "SQLConnectivityUpdateSettings": {
              "ConnectivityType": "Private",
              "Port": "1433"
          },
          "SQLWorkloadTypeUpdateSettings": {
              "SQLWorkloadType": "GENERAL"
          },
          "AdditionalFeaturesServerConfigurations": {
              "IsRServicesEnabled": "false"
          }
        }
      }
    SETTINGS
}