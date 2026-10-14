variable "name" {
  description = "Name of the AKS cluster."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group for the cluster."
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version (e.g. \"1.31\"). Null lets AKS pick its current default."
  type        = string
  default     = null
}

variable "sku_tier" {
  description = "AKS tier: Free, Standard (financially backed SLA) or Premium."
  type        = string
  default     = "Free"

  validation {
    condition     = contains(["Free", "Standard", "Premium"], var.sku_tier)
    error_message = "sku_tier must be Free, Standard or Premium."
  }
}

variable "automatic_upgrade_channel" {
  description = "Automatic cluster upgrade channel: none, patch, stable, rapid or node-image."
  type        = string
  default     = "patch"
}

variable "private_cluster_enabled" {
  description = "Expose the API server only on a private endpoint."
  type        = bool
  default     = false
}

variable "api_server_authorized_ip_ranges" {
  description = "CIDR ranges allowed to reach a public API server. Ignored for private clusters."
  type        = list(string)
  default     = []
}

variable "vnet_subnet_id" {
  description = "ID of the subnet that hosts the node pools."
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace for Container Insights and diagnostic logs."
  type        = string
}

variable "enable_entra_integration" {
  description = "Enable Microsoft Entra ID integration with Azure RBAC for Kubernetes authorization."
  type        = bool
  default     = true
}

variable "admin_group_object_ids" {
  description = "Entra ID group object IDs that get cluster-admin."
  type        = list(string)
  default     = []
}

variable "local_account_disabled" {
  description = "Disable the local kubeconfig admin account so all access goes through Entra ID."
  type        = bool
  default     = false
}

variable "network_policy" {
  description = "Network policy engine: cilium, azure or calico."
  type        = string
  default     = "cilium"

  validation {
    condition     = contains(["cilium", "azure", "calico"], var.network_policy)
    error_message = "network_policy must be cilium, azure or calico."
  }
}

variable "pod_cidr" {
  description = "Pod CIDR for Azure CNI Overlay. Must not overlap any connected VNet."
  type        = string
  default     = "10.244.0.0/16"
}

variable "service_cidr" {
  description = "Kubernetes service CIDR. Must not overlap any connected VNet."
  type        = string
  default     = "172.16.0.0/16"
}

variable "dns_service_ip" {
  description = "IP address inside service_cidr used by CoreDNS."
  type        = string
  default     = "172.16.0.10"
}

variable "zones" {
  description = "Availability zones for node pools. Empty list means no zone placement."
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
  description = "Create a dedicated user node pool. When true the system pool only runs critical add-ons."
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

variable "maintenance_utc_offset" {
  description = "UTC offset used for the weekly upgrade window (Sunday 02:00)."
  type        = string
  default     = "+05:30"
}

variable "attach_acr" {
  description = "Grant the kubelet identity AcrPull on acr_id. A plain bool so it is known at plan time."
  type        = bool
  default     = false
}

variable "acr_id" {
  description = "Resource ID of the container registry to pull from. Required when attach_acr is true."
  type        = string
  default     = null
}

variable "enable_diagnostics" {
  description = "Send control-plane logs to Log Analytics."
  type        = bool
  default     = true
}

variable "enable_alerts" {
  description = "Create node CPU and memory metric alerts. Requires action_group_id."
  type        = bool
  default     = false
}

variable "action_group_id" {
  description = "Action group notified by the metric alerts. Required when enable_alerts is true."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}
