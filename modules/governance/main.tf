# Governance guardrails for the platform resource group:
#   * built-in Azure Policy definitions and initiatives for AKS
#   * Entra ID group -> Azure RBAC role assignments on the cluster
#   * optional CanNotDelete lock

# ---------------------------------------------------------------------------
# Azure Policy
# ---------------------------------------------------------------------------

data "azurerm_policy_definition" "this" {
  for_each     = var.policy_definitions
  display_name = each.value
}

data "azurerm_policy_set_definition" "this" {
  for_each     = var.policy_initiatives
  display_name = each.value
}

resource "azurerm_resource_group_policy_assignment" "definition" {
  for_each = var.policy_definitions

  name                 = each.key
  resource_group_id    = var.platform_resource_group_id
  policy_definition_id = data.azurerm_policy_definition.this[each.key].id
  display_name         = each.value
  description          = "Managed by Terraform (${var.name_prefix})."
  enforce              = var.policy_enforce
}

resource "azurerm_resource_group_policy_assignment" "initiative" {
  for_each = var.policy_initiatives

  name                 = each.key
  resource_group_id    = var.platform_resource_group_id
  policy_definition_id = data.azurerm_policy_set_definition.this[each.key].id
  display_name         = each.value
  description          = "Managed by Terraform (${var.name_prefix})."
  enforce              = var.policy_enforce
  parameters           = var.initiative_effect == null ? null : jsonencode({ effect = { value = var.initiative_effect } })
}

# ---------------------------------------------------------------------------
# RBAC: Entra ID groups -> Azure RBAC roles on the cluster
# ---------------------------------------------------------------------------

locals {
  admin_assignments = {
    for g in var.admin_group_object_ids :
    "admin-${g}" => { principal_id = g, role = "Azure Kubernetes Service RBAC Cluster Admin" }
  }

  reader_assignments = {
    for g in var.reader_group_object_ids :
    "reader-${g}" => { principal_id = g, role = "Azure Kubernetes Service RBAC Reader" }
  }

  # Everyone who uses the cluster needs permission to fetch a kubeconfig.
  cluster_user_assignments = {
    for g in setunion(var.admin_group_object_ids, var.reader_group_object_ids) :
    "user-${g}" => { principal_id = g, role = "Azure Kubernetes Service Cluster User Role" }
  }

  role_assignments = merge(
    local.admin_assignments,
    local.reader_assignments,
    local.cluster_user_assignments,
  )
}

resource "azurerm_role_assignment" "cluster" {
  for_each = local.role_assignments

  scope                = var.aks_cluster_id
  role_definition_name = each.value.role
  principal_id         = each.value.principal_id
  principal_type       = "Group"
}

# ---------------------------------------------------------------------------
# Optional delete lock
# ---------------------------------------------------------------------------

resource "azurerm_management_lock" "platform" {
  count = var.enable_resource_lock ? 1 : 0

  name       = "lock-${var.name_prefix}-platform"
  scope      = var.platform_resource_group_id
  lock_level = "CanNotDelete"
  notes      = "Protects the ${var.name_prefix} platform resource group from accidental deletion. Remove the lock before destructive Terraform changes."
}
