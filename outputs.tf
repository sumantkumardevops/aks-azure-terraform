output "aks_cluster_name" {
  description = "Name of the AKS cluster."
  value       = module.aks.name
}

output "aks_cluster_id" {
  description = "Resource ID of the AKS cluster."
  value       = module.aks.id
}

output "aks_resource_group" {
  description = "Resource group that contains the AKS cluster."
  value       = azurerm_resource_group.platform.name
}

output "get_credentials_command" {
  description = "Command that fetches a kubeconfig for the cluster."
  value       = "az aks get-credentials --resource-group ${azurerm_resource_group.platform.name} --name ${module.aks.name}"
}

output "aks_oidc_issuer_url" {
  description = "OIDC issuer URL for workload identity federation."
  value       = module.aks.oidc_issuer_url
}

output "acr_login_server" {
  description = "Container registry login server."
  value       = module.acr.login_server
}

output "log_analytics_workspace_id" {
  description = "Resource ID of the Log Analytics workspace."
  value       = module.monitoring.workspace_id
}

output "hub_vnet_id" {
  description = "Resource ID of the hub VNet."
  value       = module.network.hub_vnet_id
}

output "spoke_vnet_id" {
  description = "Resource ID of the spoke VNet."
  value       = module.network.spoke_vnet_id
}
