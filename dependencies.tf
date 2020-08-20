resource "random_id" "suffix" {
  byte_length = 4
}

resource "azurerm_resource_group" "win-vmss" {
  name     = "${var.prefix}-rg"
  location = var.location
  tags     = var.tags
}

resource "azurerm_virtual_network" "win-vmss" {
  name                = "${var.prefix}-vnet"
  address_space       = [var.address_space]
  location            = azurerm_resource_group.win-vmss.location
  resource_group_name = azurerm_resource_group.win-vmss.name
  tags                = var.tags
}

resource "azurerm_subnet" "win-vmss" {
  name                 = var.subnet_names[count.index]
  resource_group_name  = azurerm_resource_group.win-vmss.name
  virtual_network_name = azurerm_virtual_network.win-vmss.name
  count                = length(var.subnet_names)
  address_prefixes     = [var.subnet_prefixes[count.index]]
}

resource "azurerm_network_security_group" "win-vmss" {
  name                = "${var.prefix}-base-sg"
  location            = azurerm_resource_group.win-vmss.location
  resource_group_name = azurerm_resource_group.win-vmss.name

  security_rule {
    name              = "${var.prefix}-base-ports"
    priority          = 100
    direction         = "Inbound"
    access            = "Allow"
    protocol          = "Tcp"
    source_port_range = "*"
    destination_port_ranges = [
      "80",
      "443",
      "3389",
      "5895",
      "5986"
    ]
    source_address_prefix      = var.router_wan_ip
    destination_address_prefix = "*"
  }
  tags = var.tags
}

resource "azurerm_subnet_network_security_group_association" "win-vmss" {
  subnet_id                 = azurerm_subnet.win-vmss[count.index].id
  network_security_group_id = azurerm_network_security_group.win-vmss.id
  count                     = length(var.subnet_names)
}

resource "azurerm_storage_account" "win-vmss" {
  name                = "linuxvmssdiag${random_id.suffix.hex}"
  location            = azurerm_resource_group.win-vmss.location
  resource_group_name = azurerm_resource_group.win-vmss.name

  access_tier               = "Hot"
  account_kind              = "StorageV2"
  account_replication_type  = "LRS"
  account_tier              = "Standard"
  enable_https_traffic_only = true
  is_hns_enabled            = false

  tags = var.tags
}
