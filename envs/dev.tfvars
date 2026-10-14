# Dev: smallest footprint. One system node pool runs everything, no zones,
# Free AKS tier, Basic registry. Run `make destroy ENV=dev` when you are done.

environment         = "dev"
location            = "centralindia"
hub_address_space   = "10.10.0.0/24"
spoke_address_space = "10.10.16.0/20"

# AKS
sku_tier              = "Free"
zones                 = []
enable_user_node_pool = false
system_node_pool = {
  vm_size   = "Standard_D2s_v5"
  min_count = 1
  max_count = 2
}
local_account_disabled = false # keep kubeconfig admin access while experimenting

# Entra ID group object IDs (find them with: az ad group show --group "<name>" --query id -o tsv)
aks_admin_group_object_ids  = []
aks_reader_group_object_ids = []

# Registry, monitoring, governance
acr_sku               = "Basic"
log_retention_days    = 30
enable_alerts         = false
alert_email_addresses = []
enable_resource_lock  = false
