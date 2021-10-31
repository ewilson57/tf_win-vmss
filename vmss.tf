data "azurerm_shared_image" "win-iis" {
  name                = "win-2022-azure-iis"
  gallery_name        = "shared_image_gallery_1"
  resource_group_name = "management-rg"
}

resource "azurerm_windows_virtual_machine_scale_set" "win-vmss" {
  name                 = var.prefix
  computer_name_prefix = var.prefix
  location             = azurerm_resource_group.win-vmss.location
  resource_group_name  = azurerm_resource_group.win-vmss.name
  sku                  = "Standard_DS1_v2"
  instances            = 2
  admin_username       = var.admin_username
  admin_password       = var.admin_password

  source_image_id = data.azurerm_shared_image.win-iis.id

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }

  network_interface {
    name    = "${var.prefix}-nic"
    primary = true

    ip_configuration {
      name                                   = "internal"
      primary                                = true
      subnet_id                              = azurerm_subnet.win-vmss[1].id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.win-vmss-bpepool.id]
      load_balancer_inbound_nat_rules_ids    = [azurerm_lb_nat_pool.natpool.id]
    }
  }
  depends_on = [azurerm_lb_rule.win-vmss-lb-rule]
}

resource "azurerm_public_ip" "win-vmss-public-ip" {
  name                    = "${var.prefix}-public-ip"
  resource_group_name     = azurerm_resource_group.win-vmss.name
  allocation_method       = "Static"
  idle_timeout_in_minutes = 4
  ip_version              = "IPv4"
  location                = var.location
  sku                     = "Standard"
}

resource "azurerm_lb" "win-vmss-lb" {
  location            = var.location
  name                = "win-vmss-lb"
  resource_group_name = azurerm_resource_group.win-vmss.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                          = "PublicIPAddress"
    private_ip_address_allocation = "Dynamic"
    private_ip_address_version    = "IPv4"
    public_ip_address_id          = azurerm_public_ip.win-vmss-public-ip.id
  }
}

resource "azurerm_lb_backend_address_pool" "win-vmss-bpepool" {
  loadbalancer_id = azurerm_lb.win-vmss-lb.id
  name            = "bepool"
}

resource "azurerm_lb_probe" "win-vmss-lb-probe" {
  resource_group_name = azurerm_resource_group.win-vmss.name
  loadbalancer_id     = azurerm_lb.win-vmss-lb.id
  name                = "http-probe"
  port                = var.application_port
}

resource "azurerm_lb_rule" "win-vmss-lb-rule" {
  resource_group_name            = azurerm_resource_group.win-vmss.name
  loadbalancer_id                = azurerm_lb.win-vmss-lb.id
  name                           = "http"
  protocol                       = "Tcp"
  frontend_port                  = var.application_port
  backend_port                   = var.application_port
  frontend_ip_configuration_name = azurerm_lb.win-vmss-lb.frontend_ip_configuration.0.name
  probe_id                       = azurerm_lb_probe.win-vmss-lb-probe.id
}

resource "azurerm_lb_nat_pool" "natpool" {
  resource_group_name            = azurerm_resource_group.win-vmss.name
  loadbalancer_id                = azurerm_lb.win-vmss-lb.id
  name                           = "natpool"
  protocol                       = "Tcp"
  frontend_port_start            = 50000
  frontend_port_end              = 50099
  backend_port                   = 3389
  frontend_ip_configuration_name = azurerm_lb.win-vmss-lb.frontend_ip_configuration.0.name
}

output "public_ip_addr" {
  value = azurerm_public_ip.win-vmss-public-ip.ip_address
}
