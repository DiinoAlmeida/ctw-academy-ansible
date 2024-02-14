# Random identifier to avoid collisions
resource "random_string" "number" {
  length  = 4
  upper   = false
  lower   = false
  numeric = true
  special = false
}

# Create virtual network
resource "azurerm_virtual_network" "myterraformnetwork" {
  name                = "vnet${random_string.number.result}"
  address_space       = ["10.0.0.0/16"]
  location            = var.resource_group_location
  resource_group_name = var.resource_group_name
}

# Create subnet
resource "azurerm_subnet" "my_tf_subnet" {
  name                  = "subnet${random_string.number.result}"
  resource_group_name   = var.resource_group_name
  virtual_network_name  = azurerm_virtual_network.myterraformnetwork.name
  address_prefixes      = ["10.0.1.0/24"]
}

# Create public IPs
resource "azurerm_public_ip" "my_tf_public_ip" {
  name                  = "publicIP${random_string.number.result}"
  location              = var.resource_group_location
  resource_group_name   = var.resource_group_name
  allocation_method     = "Dynamic"
  domain_name_label     = "myvm03467" 
}


# Create Network Security Group and rule
resource "azurerm_network_security_group" "my_tf_nsg" {
  name                = "myNetworkSecurityGroup${random_string.number.result}"
  location            = var.resource_group_location
  resource_group_name = var.resource_group_name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "NodeExporter"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "9100"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "http"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "https"
    priority                   = 1004
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  
}

# Create network interface
resource "azurerm_network_interface" "my_tf_nic" {
  name                  = "nic${random_string.number.result}"
  location              = var.resource_group_location
  resource_group_name   = var.resource_group_name

  ip_configuration {
    name                          = "my_nic_config"
    subnet_id                     = azurerm_subnet.my_tf_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.my_tf_public_ip.id
  }
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "example" {
  network_interface_id        = azurerm_network_interface.my_tf_nic.id
  network_security_group_id   = azurerm_network_security_group.my_tf_nsg.id
}

# Create virtual machine
resource "azurerm_linux_virtual_machine" "my_tf_vm" {
  name                      = "VM03467"
  admin_username            = "CTW03467"
  location                  = var.resource_group_location
  resource_group_name       = var.resource_group_name
  network_interface_ids     = [azurerm_network_interface.my_tf_nic.id]
  size                      = "Standard_DS1_v2"

  os_disk {
    #name                  = "myOsDisk"
    caching               = "ReadWrite"
    storage_account_type  = "Premium_LRS" 
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  admin_ssh_key {
    username = var.username
    public_key = file("../resources/id_rsa.pub")
  }
}