# ---------------------------------------------------------------------------
# General
# ---------------------------------------------------------------------------

variable "project" {
  description = "Short project name used in resource names (lowercase letters, digits and hyphens)."
  type        = string
  default     = "aksplat"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,11}$", var.project))
    error_message = "project must start with a letter, be 2-12 characters, and contain only lowercase letters, digits and hyphens."
  }
}

variable "environment" {
  description = "Deployment environment."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging or prod."
  }
}

variable "location" {
  description = "Azure region."
  type        = string
  default     = "centralindia"
}

variable "tags" {
  description = "Extra tags merged into the default tag set."
  type        = map(string)
  default     = {}
}

# ---------------------------------------------------------------------------
# Network
# ---------------------------------------------------------------------------

variable "hub_address_space" {
  description = "CIDR of the hub VNet. A /24 is carved into subnets automatically."
  type        = string

  validation {
    condition     = can(cidrhost(var.hub_address_space, 0))
    error_message = "hub_address_space must be a valid CIDR block."
  }
}

variable "spoke_address_space" {
  description = "CIDR of the spoke VNet. Must be a /20 or larger so the AKS and private-endpoint subnets fit."
  type        = string

  validation {
    condition     = can(cidrhost(var.spoke_address_space, 0)) && tonumber(split("/", var.spoke_address_space)[1]) <= 20
    error_message = "spoke_address_space must be a valid CIDR block of /20 or larger."
  }
}

# ---------------------------------------------------------------------------
# AKS
# ---------------------------------------------------------------------------

variable "kubernetes_version" {
  description = "Kubernetes minor version (e.g. \"1.31\"). Null uses the AKS default for the region."
  type        = string
  default     = null
}

variable "sku_tier" {
  description = "AKS tier: Free, Standard (financially backed SLA) or Premium."
  type        = string
  default     = "Free"
}

variable "private_cluster_enabled" {
  description = "Expose the API server only through a private endpoint."
  type        = bool
  default     = false
}

variable "api_server_authorized_ip_ranges" {
  description = "CIDR ranges allowed to reach a public API server. Empty means open to the internet (still Entra ID authenticated)."
  type        = list(string)
  default     = []
}

variable "network_policy" {
  description = "Network policy engine: cilium, azure or calico."
  type        = string
  default     = "cilium"
}

variable "zones" {
  description = "Availability zones for node pools. Use [] for regions or quotas without zone support."
  type        = list(string)
  default     = []
}

variable "system_node_pool" {
  description = "Sizing of the system node pool."
  type = object({
    vm_size         = string
    min_count       = number
    max_count       = number
    os_disk_size_gb = optional(number, 64)
  })
}

variable "enable_user_node_pool" {
  description = "Create a dedicated user node pool. When false, workloads run on the system pool (cheaper, dev only)."
  type        = bool
  default     = true
}

variable "user_node_pool" {
  description = "Sizing of the user node pool."
  type = object({
    vm_size         = string
    min_count       = number
    max_count       = number
    os_disk_size_gb = optional(number, 64)
  })
  default = {
    vm_size   = "Standard_D2s_v5"
    min_count = 1
    max_count = 3
  }
}

variable "local_account_disabled" {
  description = "Disable the local kubeconfig admin account so every login goes through Entra ID. Requires aks_admin_group_object_ids."
  type        = bool
  default     = false
}

variable "aks_admin_group_object_ids" {
  description = "Entra ID group object IDs granted cluster-admin on the cluster."
  type        = list(string)
  default     = []
}

variable "aks_reader_group_object_ids" {
  description = "Entra ID group object IDs granted read-only access on the cluster."
  type        = list(string)
  default     = []
}

# ---------------------------------------------------------------------------
# Registry, monitoring and governance
# ---------------------------------------------------------------------------

variable "acr_sku" {
  description = "Container registry SKU: Basic, Standard or Premium."
  type        = string
  default     = "Basic"
}

variable "log_retention_days" {
  description = "Log Analytics retention in days."
  type        = number
  default     = 30
}

variable "enable_alerts" {
  description = "Create node CPU and memory alerts on the cluster."
  type        = bool
  default     = false
}

variable "alert_email_addresses" {
  description = "Email addresses notified by the alert action group."
  type        = list(string)
  default     = []
}

variable "policy_enforce" {
  description = "Enforce the assigned Azure Policy effects (the built-ins default to Audit)."
  type        = bool
  default     = true
}

variable "policy_initiative_effect" {
  description = "Optional effect (Audit, Deny, Disabled) for the pod-security initiative. Null keeps the built-in default (Audit)."
  type        = string
  default     = null
}

variable "enable_resource_lock" {
  description = "Apply a CanNotDelete lock to the platform resource group (blocks Terraform deletes inside it too)."
  type        = bool
  default     = false
}
