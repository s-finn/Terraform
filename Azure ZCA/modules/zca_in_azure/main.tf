/*
This module deploys a Zerto ZCA VM in Azure. The module configures a storage account, managed identity, vnet, resource group, public ip, and leverages an azure custom extension
to silently install Zerto into the specified Azure environment. 
*/

provider "azurerm" {
  features {}
}

# Create a resource group
resource "azurerm_resource_group" "rg" {
  name     = "enterrgname"
  location = "enterregionlocation"
}

#Create Managed Identity for ZCA VM
resource "azurerm_user_assigned_identity" "identity"{
  resource_group_name = azurerm_resource_group.rg.name
  location = azurerm_resource_group.rg.location
  name = "zerto-zca-managed-identity"
}

#Gather Subscription ID
data "azurerm_subscription" "primary" {
  depends_on = [azurerm_user_assigned_identity.identity]
  #subscription_id = "enterid"
}

#Create storage account for Zerto access
resource "azurerm_storage_account" "zca-storage" {
  name                     = "enterstorageaccountname"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind = "Storage"
}

#Attach Contributor Role to Managed Identity 
resource "azurerm_role_assignment" "contributor-role" {
  scope                = data.azurerm_subscription.primary.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.identity.principal_id
}

#Attach Storage Blob Contributor Role to Managed Identity
resource "azurerm_role_assignment" "data-role" {
  scope                = data.azurerm_subscription.primary.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.identity.principal_id
}

#Attach Storage Queue Data Contributor Role to Managed Identity
resource "azurerm_role_assignment" "queue-role" {
  scope                = data.azurerm_subscription.primary.id
  role_definition_name = "Storage Queue Data Contributor"
  principal_id         = azurerm_user_assigned_identity.identity.principal_id
}

# Create virtual network
resource "azurerm_virtual_network" "vnet" {
  name                = "entervnetname"
  address_space       = ["enterIP"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Create subnet
resource "azurerm_subnet" "subnet" {
  name                 = "entersubnetname"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["enterIP"]
}

# Create public IP
# Remove before deploying if Public IP is not wanted
resource "azurerm_public_ip" "publicip" {
  name                = "enterpublicIP"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
}

# Create Network Security Group and rule
# Remove security rules if ZCA will have restricted access
resource "azurerm_network_security_group" "nsg" {
  name                = "enterNSGName"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "RDP"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
    security_rule {
    name                       = "ZertoHttps"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "9669"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Create network interface
resource "azurerm_network_interface" "nic" {
  name                      = "enternicname"
  location                  = azurerm_resource_group.rg.location
  resource_group_name       = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "enterIPname"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "dynamic"
    public_ip_address_id          = azurerm_public_ip.publicip.id
  }
}

# Create  Windows VM for ZCA
resource "azurerm_windows_virtual_machine" "vm" {
  name                  = "enterVMname"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.nic.id]
  size               = "Standard_DS3_v2"
  admin_username = "enteruser"
  admin_password = "enterpassword"

  os_disk {
    caching           = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }


  source_image_reference {
    publisher = "zerto"
    offer     = "zerto-vms"
    sku       = "zerto8"
    version   = "latest"
  }
  plan {
      name = "zerto8"
      publisher = "zerto"
      product = "zerto-vms"
  }

  identity{
    type = "UserAssigned"
  
    identity_ids = [
      azurerm_user_assigned_identity.identity.id,
    ]
  }




}

#Create VM Extension to perform silent install of Zerto
resource "azurerm_virtual_machine_extension" "zertoinstall" {
  depends_on=[azurerm_windows_virtual_machine.vm]

  name                 = "zerto"
  virtual_machine_id   = azurerm_windows_virtual_machine.vm.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.9"

  settings = <<SETTINGS
    { 
      "commandToExecute": "powershell.exe -command & \"C:\\Temp\\Zerto ZCA Azure Installer.exe\" -l c:\\temp\\install.log -s Sitename=${azurerm_windows_virtual_machine.vm.name} RegionId=\"${azurerm_network_security_group.nsg.location}\" ResourceGroupName=${azurerm_resource_group.rg.name} StorageAccountName=${azurerm_storage_account.zca-storage.name}"
    } 
  SETTINGS

}

#Create Public IP Address for VM access
data "azurerm_public_ip" "ip" {
  name                = azurerm_public_ip.publicip.name
  resource_group_name = azurerm_windows_virtual_machine.vm.resource_group_name
  depends_on          = [azurerm_windows_virtual_machine.vm]
}

#Output Public IP Address
output "public_ip_address" {
  value = data.azurerm_public_ip.ip.ip_address
}


