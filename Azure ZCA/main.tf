
provider "azurerm" {
  features {}
}

# Create a resource group
resource "azurerm_resource_group" "rg" {
  name     = "ZertoZCA"
  location = "eastus2"
}

resource "azurerm_user_assigned_identity" "identity"{
  resource_group_name = azurerm_resource_group.rg.name
  location = azurerm_resource_group.rg.location
  name = "zerto-zca-managed-identity"
}

data "azurerm_subscription" "primary" {
  depends_on = ["azurerm_user_assigned_identity.identity"]
  #subscription_id = "enterid"
}


resource "azurerm_role_assignment" "contributor-role" {
  scope                = data.azurerm_subscription.primary.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.identity.principal_id
}

resource "azurerm_role_assignment" "data-role" {
  scope                = data.azurerm_subscription.primary.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.identity.principal_id
}

resource "azurerm_role_assignment" "queue-role" {
  scope                = data.azurerm_subscription.primary.id
  role_definition_name = "Storage Queue Data Contributor"
  principal_id         = azurerm_user_assigned_identity.identity.principal_id
}

# Create virtual network
resource "azurerm_virtual_network" "vnet" {
  name                = "ZertovNet"
  address_space       = ["10.0.0.0/16"]
  location            = "eastus2"
  resource_group_name = azurerm_resource_group.rg.name
}

# Create subnet
resource "azurerm_subnet" "subnet" {
  name                 = "ZCASubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Create public IP
resource "azurerm_public_ip" "publicip" {
  name                = "ZCAPublicIP"
  location            = "eastus2"
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
}


# Create Network Security Group and rule
resource "azurerm_network_security_group" "nsg" {
  name                = "ZertoNSG"
  location            = "eastus2"
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
  name                      = "ZCANIC"
  location                  = "eastus2"
  resource_group_name       = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ZCANICConfg"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "dynamic"
    public_ip_address_id          = azurerm_public_ip.publicip.id
  }
}


# Create a Windows VM virtual machine
resource "azurerm_windows_virtual_machine" "vm" {
  name                  = "ZCAVM"
  location              = "eastus2"
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.nic.id]
  size               = "Standard_DS3_v2"
  admin_username = "Shaun"
  admin_password = "Zertodata1!"

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
      "${azurerm_user_assigned_identity.identity.id}",
    ]
  }

  provisioner "local-exec"{
    command = "powershell.exe az vm run-command invoke --command-id RunPowerShellScript --name zcavm --resource-group zertozca --scripts @azure-zca.ps1"
  }

}

data "azurerm_public_ip" "ip" {
  name                = azurerm_public_ip.publicip.name
  resource_group_name = azurerm_windows_virtual_machine.vm.resource_group_name
  depends_on          = [azurerm_windows_virtual_machine.vm]
}

output "public_ip_address" {
  value = data.azurerm_public_ip.ip.ip_address
}


