output "id" {
  description = "Resource ID of the registry."
  value       = azurerm_container_registry.this.id
}

output "name" {
  description = "Name of the registry."
  value       = azurerm_container_registry.this.name
}

output "login_server" {
  description = "Login server hostname, e.g. myacr.azurecr.io."
  value       = azurerm_container_registry.this.login_server
}
