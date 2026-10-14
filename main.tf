locals {
  name_prefix = "${var.project}-${var.environment}"

  tags = merge(
    {
      project     = var.project
      environment = var.environment
      managed_by  = "terraform"
    },
    var.tags,
  )

  # Subnets are derived from the VNet CIDRs so each environment only needs two
  # address spaces in its tfvars file.
  #
  #   hub   /24 -> shared-services /26
  #   spoke /20 -> aks /22, private-endpoints /24
  hub_subnets = {
    "shared-services" = {
      address_prefixes = [cidrsubnet(var.hub_address_space, 2, 0)]
    }
  }

  spoke_subnets = {
    aks = {
      address_prefixes = [cidrsubnet(var.spoke_address_space, 2, 0)]
      nsg_rules = [
        {
          name                   = "AllowHttpsInbound"
          priority               = 100
          direction              = "Inbound"
          access                 = "Allow"
          protocol               = "Tcp"
          destination_port_range = "443"
          source_address_prefix  = "Internet"
        },
        {
          name                   = "AllowHttpInbound"
          priority               = 110
          direction              = "Inbound"
          access                 = "Allow"
          protocol               = "Tcp"
          destination_port_range = "80"
          source_address_prefix  = "Internet"
        },
      ]
    }

    "private-endpoints" = {
      address_prefixes = [cidrsubnet(var.spoke_address_space, 4, 4)]
    }
  }
}

# Short random suffix that keeps globally unique names (the registry) unique.
resource "random_string" "suffix" {
  length  = 5
  special = false
  upper   = false
}

# ---------------------------------------------------------------------------
# Resource groups
# ---------------------------------------------------------------------------

resource "azurerm_resource_group" "network" {
  name     = "rg-${local.name_prefix}-network"
  location = var.location
  tags     = local.tags
}

resource "azurerm_resource_group" "platform" {
  name     = "rg-${local.name_prefix}-platform"
  location = var.location
  tags     = local.tags
}

# ---------------------------------------------------------------------------
# Modules
# ---------------------------------------------------------------------------

module "network" {
  source = "./modules/network"

  name_prefix         = local.name_prefix
  location            = var.location
  resource_group_name = azurerm_resource_group.network.name
  hub_address_space   = var.hub_address_space
  spoke_address_space = var.spoke_address_space
  hub_subnets         = local.hub_subnets
  spoke_subnets       = local.spoke_subnets
  tags                = local.tags
}

module "monitoring" {
  source = "./modules/monitoring"

  name_prefix             = local.name_prefix
  location                = var.location
  resource_group_name     = azurerm_resource_group.platform.name
  retention_in_days       = var.log_retention_days
  action_group_short_name = substr(replace(local.name_prefix, "-", ""), 0, 12)
  alert_email_addresses   = var.alert_email_addresses
  tags                    = local.tags
}

module "acr" {
  source = "./modules/acr"

  name                = "acr${replace(var.project, "-", "")}${var.environment}${random_string.suffix.result}"
  location            = var.location
  resource_group_name = azurerm_resource_group.platform.name
  sku                 = var.acr_sku
  tags                = local.tags
}

module "aks" {
  source = "./modules/aks"

  name                = "aks-${local.name_prefix}"
  location            = var.location
  resource_group_name = azurerm_resource_group.platform.name

  kubernetes_version              = var.kubernetes_version
  sku_tier                        = var.sku_tier
  private_cluster_enabled         = var.private_cluster_enabled
  api_server_authorized_ip_ranges = var.api_server_authorized_ip_ranges
  network_policy                  = var.network_policy
  zones                           = var.zones

  vnet_subnet_id             = module.network.spoke_subnet_ids["aks"]
  log_analytics_workspace_id = module.monitoring.workspace_id

  system_node_pool      = var.system_node_pool
  enable_user_node_pool = var.enable_user_node_pool
  user_node_pool        = var.user_node_pool

  enable_entra_integration = true
  admin_group_object_ids   = var.aks_admin_group_object_ids
  local_account_disabled   = var.local_account_disabled

  attach_acr = true
  acr_id     = module.acr.id

  enable_alerts   = var.enable_alerts
  action_group_id = module.monitoring.action_group_id

  tags = local.tags
}

module "governance" {
  source = "./modules/governance"

  name_prefix                = local.name_prefix
  platform_resource_group_id = azurerm_resource_group.platform.id
  aks_cluster_id             = module.aks.id

  policy_enforce          = var.policy_enforce
  initiative_effect       = var.policy_initiative_effect
  admin_group_object_ids  = var.aks_admin_group_object_ids
  reader_group_object_ids = var.aks_reader_group_object_ids
  enable_resource_lock    = var.enable_resource_lock
}
