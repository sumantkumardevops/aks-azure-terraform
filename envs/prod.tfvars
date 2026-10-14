# Prod: Standard tier (financially backed SLA), zone-spread node pools,
# Entra-only access, Premium registry, longer log retention, delete lock.

environment         = "prod"
location            = "centralindia"
hub_address_space   = "10.30.0.0/24"
spoke_address_space = "10.30.16.0/20"

# AKS
sku_tier              = "Standard"
zones                 = ["1", "2", "3"]
enable_user_node_pool = true
system_node_pool = {
  vm_size   = "Standard_D4s_v5"
  min_count = 3
  max_count = 5
}
user_node_pool = {
  vm_size   = "Standard_D4s_v5"
  min_count = 3
  max_count = 10
}

# Set to true for a private API server (then use a jump host, VPN or
# `az aks command invoke` to reach it), and/or restrict the public one:
private_cluster_enabled = false
# api_server_authorized_ip_ranges = ["203.0.113.0/24"]

# REQUIRED for prod: the local admin account is disabled, so at least one Entra
# ID group must be admin or the plan fails (guardrail against locking yourself out).
local_account_disabled      = true
aks_admin_group_object_ids  = [] # e.g. ["00000000-0000-0000-0000-000000000000"]
aks_reader_group_object_ids = []

# Registry, monitoring, governance
acr_sku               = "Premium"
log_retention_days    = 90
enable_alerts         = true
alert_email_addresses = [] # e.g. ["oncall@example.com"]

# The lock also blocks Terraform from deleting/replacing resources in the
# platform resource group; remove it first for destructive changes.
enable_resource_lock = true
