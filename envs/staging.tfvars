# Staging: production-shaped (zones, dedicated user pool, alerts) but small
# and on the Free AKS tier.

environment         = "staging"
location            = "centralindia"
hub_address_space   = "10.20.0.0/24"
spoke_address_space = "10.20.16.0/20"

# AKS
sku_tier              = "Free"
zones                 = ["1", "2", "3"]
enable_user_node_pool = true
system_node_pool = {
  vm_size   = "Standard_D2s_v5"
  min_count = 1
  max_count = 3
}
user_node_pool = {
  vm_size   = "Standard_D2s_v5"
  min_count = 1
  max_count = 3
}
local_account_disabled = false

# Entra ID group object IDs (find them with: az ad group show --group "<name>" --query id -o tsv)
aks_admin_group_object_ids  = []
aks_reader_group_object_ids = []

# Registry, monitoring, governance
acr_sku               = "Standard"
log_retention_days    = 30
enable_alerts         = true
alert_email_addresses = [] # e.g. ["oncall@example.com"]
enable_resource_lock  = false
