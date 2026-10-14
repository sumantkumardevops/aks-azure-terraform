variable "name_prefix" {
  description = "Prefix used in resource names, e.g. aksplat-dev."
  type        = string
}

variable "platform_resource_group_id" {
  description = "Resource group ID that policies are assigned to and that the optional lock protects."
  type        = string
}

variable "aks_cluster_id" {
  description = "Resource ID of the AKS cluster that RBAC roles are granted on."
  type        = string
}

variable "policy_definitions" {
  description = <<-EOT
    Built-in Azure Policy definitions to assign, as { assignment-name = "exact display name" }.
    Display names are looked up at plan time. If Microsoft renames one, the plan fails with a
    clear error; find the current name with: az policy definition list --query "[?contains(displayName,'Kubernetes')].displayName"
  EOT
  type        = map(string)
  default = {
    "aks-azure-policy-addon"  = "Azure Policy Add-on for Kubernetes service (AKS) should be installed and enabled on your clusters"
    "aks-rbac-enabled"        = "Role-Based Access Control (RBAC) should be used on Kubernetes Services"
    "aks-https-only"          = "Kubernetes clusters should be accessible only over HTTPS"
    "aks-local-auth-disabled" = "Azure Kubernetes Service Clusters should have local authentication methods disabled"
    "aks-private-cluster"     = "Azure Kubernetes Service Private Clusters should be enabled"
  }
}

variable "policy_initiatives" {
  description = "Built-in Azure Policy initiatives (policy sets) to assign, as { assignment-name = \"exact display name\" }."
  type        = map(string)
  default = {
    "aks-pod-security-baseline" = "Kubernetes cluster pod security baseline standards for Linux-based workloads"
  }
}

variable "policy_enforce" {
  description = "Enforce the policy effects. The defaults of these built-ins are Audit, so nothing is blocked unless an effect is set to Deny."
  type        = bool
  default     = true
}

variable "initiative_effect" {
  description = "Optional effect (Audit, Deny or Disabled) passed to the initiatives as their effect parameter. Null keeps the built-in default (Audit)."
  type        = string
  default     = null

  validation {
    condition     = var.initiative_effect == null || contains(["Audit", "Deny", "Disabled"], coalesce(var.initiative_effect, "Audit"))
    error_message = "initiative_effect must be null, Audit, Deny or Disabled."
  }
}

variable "admin_group_object_ids" {
  description = "Entra ID groups granted Azure Kubernetes Service RBAC Cluster Admin."
  type        = list(string)
  default     = []
}

variable "reader_group_object_ids" {
  description = "Entra ID groups granted Azure Kubernetes Service RBAC Reader."
  type        = list(string)
  default     = []
}

variable "enable_resource_lock" {
  description = "Apply a CanNotDelete lock to the platform resource group. Note that the lock also blocks Terraform from deleting or replacing resources inside it."
  type        = bool
  default     = false
}
