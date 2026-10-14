resource "azurerm_container_registry" "this" {
  name                          = var.name
  location                      = var.location
  resource_group_name           = var.resource_group_name
  sku                           = var.sku
  admin_enabled                 = false # pull via managed identity (AcrPull), never shared credentials
  anonymous_pull_enabled        = false
  public_network_access_enabled = true # set false and add a private endpoint (Premium) for locked-down setups
  tags                          = var.tags
}
