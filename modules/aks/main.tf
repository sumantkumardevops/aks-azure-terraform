# AKS cluster with:
#   * user-assigned control-plane identity
#   * Azure CNI Overlay + Cilium network policy
#   * Entra ID integration with Azure RBAC for Kubernetes
#   * workload identity (OIDC issuer), Azure Policy add-on, Container Insights
#   * autoscaling system pool and optional user pool, spread across zones
#   * weekly planned-maintenance window

resource "azurerm_user_assigned_identity" "cluster" {
  name                = "id-${var.name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# With a custom VNet the cluster identity must be able to join nodes and
# create load balancer rules on the node subnet.
resource "azurerm_role_assignment" "network_contributor" {
  scope                            = var.vnet_subnet_id
  role_definition_name             = "Network Contributor"
  principal_id                     = azurerm_user_assigned_identity.cluster.principal_id
  skip_service_principal_aad_check = true # new identity may not have replicated to Entra ID yet
}

resource "azurerm_kubernetes_cluster" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = var.name
  node_resource_group = "rg-${var.name}-nodes"
  kubernetes_version  = var.kubernetes_version
  sku_tier            = var.sku_tier

  private_cluster_enabled   = var.private_cluster_enabled
  local_account_disabled    = var.local_account_disabled
  oidc_issuer_enabled       = true
  workload_identity_enabled = true
  azure_policy_enabled      = true

  image_cleaner_enabled        = true
  image_cleaner_interval_hours = 48

  automatic_upgrade_channel = var.automatic_upgrade_channel
  node_os_upgrade_channel   = "NodeImage"

  dynamic "api_server_access_profile" {
    for_each = (!var.private_cluster_enabled && length(var.api_server_authorized_ip_ranges) > 0) ? [1] : []
    content {
      authorized_ip_ranges = var.api_server_authorized_ip_ranges
    }
  }

  default_node_pool {
    name                         = "system"
    vm_size                      = var.system_node_pool.vm_size
    auto_scaling_enabled         = true
    min_count                    = var.system_node_pool.min_count
    max_count                    = var.system_node_pool.max_count
    os_disk_size_gb              = var.system_node_pool.os_disk_size_gb
    vnet_subnet_id               = var.vnet_subnet_id
    zones                        = length(var.zones) > 0 ? var.zones : null
    only_critical_addons_enabled = var.enable_user_node_pool
    temporary_name_for_rotation  = "systemtmp"

    upgrade_settings {
      max_surge = "33%"
    }

    tags = var.tags
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.cluster.id]
  }

  dynamic "azure_active_directory_role_based_access_control" {
    for_each = var.enable_entra_integration ? [1] : []
    content {
      azure_rbac_enabled     = true
      admin_group_object_ids = var.admin_group_object_ids
    }
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_data_plane  = var.network_policy == "cilium" ? "cilium" : "azure"
    network_policy      = var.network_policy
    load_balancer_sku   = "standard"
    outbound_type       = "loadBalancer"
    pod_cidr            = var.pod_cidr
    service_cidr        = var.service_cidr
    dns_service_ip      = var.dns_service_ip
  }

  oms_agent {
    log_analytics_workspace_id      = var.log_analytics_workspace_id
    msi_auth_for_monitoring_enabled = true
  }

  maintenance_window_auto_upgrade {
    frequency   = "Weekly"
    interval    = 1
    duration    = 4
    day_of_week = "Sunday"
    start_time  = "02:00"
    utc_offset  = var.maintenance_utc_offset
  }

  tags = var.tags

  depends_on = [azurerm_role_assignment.network_contributor]

  lifecycle {
    # The autoscaler owns the node count after creation.
    ignore_changes = [default_node_pool[0].node_count]

    precondition {
      condition     = !var.local_account_disabled || (var.enable_entra_integration && length(var.admin_group_object_ids) > 0)
      error_message = "local_account_disabled = true requires enable_entra_integration = true and at least one admin_group_object_ids entry, otherwise nobody can administer the cluster."
    }
  }
}

resource "azurerm_kubernetes_cluster_node_pool" "user" {
  count = var.enable_user_node_pool ? 1 : 0

  name                  = "user"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.this.id
  mode                  = "User"
  vm_size               = var.user_node_pool.vm_size
  auto_scaling_enabled  = true
  min_count             = var.user_node_pool.min_count
  max_count             = var.user_node_pool.max_count
  os_disk_size_gb       = var.user_node_pool.os_disk_size_gb
  vnet_subnet_id        = var.vnet_subnet_id
  zones                 = length(var.zones) > 0 ? var.zones : null
  node_labels           = { workload = "apps" }

  upgrade_settings {
    max_surge = "33%"
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [node_count]
  }
}

# Let the kubelet identity pull images from the registry.
resource "azurerm_role_assignment" "acr_pull" {
  count = var.attach_acr ? 1 : 0

  scope                            = var.acr_id
  role_definition_name             = "AcrPull"
  principal_id                     = azurerm_kubernetes_cluster.this.kubelet_identity[0].object_id
  skip_service_principal_aad_check = true
}

# Control-plane logs. kube-audit-admin is much cheaper than kube-audit
# because it leaves out get/list requests.
resource "azurerm_monitor_diagnostic_setting" "aks" {
  count = var.enable_diagnostics ? 1 : 0

  name                       = "diag-${var.name}"
  target_resource_id         = azurerm_kubernetes_cluster.this.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  dynamic "enabled_log" {
    for_each = toset([
      "kube-apiserver",
      "kube-audit-admin",
      "kube-controller-manager",
      "kube-scheduler",
      "cluster-autoscaler",
      "guard",
    ])
    content {
      category = enabled_log.value
    }
  }
}

# Platform metric alerts on node saturation.
resource "azurerm_monitor_metric_alert" "node_cpu" {
  count = var.enable_alerts ? 1 : 0

  name                = "${var.name}-node-cpu-high"
  resource_group_name = var.resource_group_name
  scopes              = [azurerm_kubernetes_cluster.this.id]
  description         = "Average node CPU above 80% for 15 minutes."
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"
  tags                = var.tags

  criteria {
    metric_namespace = "Microsoft.ContainerService/managedClusters"
    metric_name      = "node_cpu_usage_percentage"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }

  action {
    action_group_id = var.action_group_id
  }
}

resource "azurerm_monitor_metric_alert" "node_memory" {
  count = var.enable_alerts ? 1 : 0

  name                = "${var.name}-node-memory-high"
  resource_group_name = var.resource_group_name
  scopes              = [azurerm_kubernetes_cluster.this.id]
  description         = "Average node working-set memory above 80% for 15 minutes."
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"
  tags                = var.tags

  criteria {
    metric_namespace = "Microsoft.ContainerService/managedClusters"
    metric_name      = "node_memory_working_set_percentage"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }

  action {
    action_group_id = var.action_group_id
  }
}
