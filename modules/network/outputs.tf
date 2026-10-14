output "hub_vnet_id" {
  description = "ID of the hub virtual network."
  value       = azurerm_virtual_network.hub.id
}

output "spoke_vnet_id" {
  description = "ID of the spoke virtual network."
  value       = azurerm_virtual_network.spoke.id
}

output "hub_subnet_ids" {
  description = "Map of hub subnet short name to subnet ID."
  value       = { for k, s in azurerm_subnet.hub : k => s.id }
}

output "spoke_subnet_ids" {
  description = "Map of spoke subnet short name to subnet ID."
  value       = { for k, s in azurerm_subnet.spoke : k => s.id }
}
