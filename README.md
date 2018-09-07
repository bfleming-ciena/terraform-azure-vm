
Example usage:

####################################################################################################
# COMPUTE
#
# 
module "AZW1WSQLDW" {
  source              = "git@github.com:stonefury/terraform-azure-vm.git//"
  vm_size             = "Standard_E32-16s_v3"
  resource_group_name = "${element("${local.workspace_lists["it_apps_resource_groups"]}", var.SQL_INDEX)}"           # apps-sqlapps
  location            = "${local.workspace["location"]}"
  vm_hostname         = "AZW1WSQLDW${upper(substr(terraform.workspace,0,1))}1"
  admin_password      = "${local.workspace["windows_admin_password"]}"
  vm_os_simple        = "WindowsServer"

  vnet_subnet_id       = "${data.terraform_remote_state.network.it_apps_subnets[var.SQL_INDEX]}" # apps-sqlapps
  remote_port          = "3389"
  public_ip            = "true"
  public_ip_dns        = ["azw1wsqldw"]
  storage_account_type = "Standard_LRS"

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

  tags = {
    terraform = "true"

    Environment = "${terraform.workspace}"

    Service = "SQL"
  }

  availability_set_id = "${azurerm_availability_set.SQLAPPS.id}"
}

resource "azurerm_virtual_machine_extension" "AZW1WSQLDW_sql_extension" {
  depends_on           = ["module.AZW1WSQLDW"]
  name                 = "SqlIaasExtension"
  location             = "${local.workspace["location"]}"
  resource_group_name  = "${element("${local.workspace_lists["it_apps_resource_groups"]}", var.SQL_INDEX)}"
  virtual_machine_name = "${module.AZW1WSQLDW.hostname}"
  publisher            = "Microsoft.SqlServer.Management"
  type                 = "SqlIaaSAgent"
  type_handler_version = "1.2"

  settings = "${local.default_sql_extension}"

  tags = {
    terraform = "true"

    Environment = "${terraform.workspace}"

    Service = "SQL"
  }
}