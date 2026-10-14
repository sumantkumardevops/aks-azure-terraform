output "policy_assignment_ids" {
  description = "IDs of all policy and initiative assignments."
  value = merge(
    { for k, a in azurerm_resource_group_policy_assignment.definition : k => a.id },
    { for k, a in azurerm_resource_group_policy_assignment.initiative : k => a.id },
  )
}

output "role_assignment_ids" {
  description = "IDs of the cluster role assignments."
  value       = { for k, a in azurerm_role_assignment.cluster : k => a.id }
}
