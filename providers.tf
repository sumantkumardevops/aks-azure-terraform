# Authentication comes from the environment, never from code:
#   * locally: `az login` plus ARM_SUBSCRIPTION_ID
#   * in CI:   GitHub OIDC (ARM_USE_OIDC, ARM_CLIENT_ID, ARM_TENANT_ID, ARM_SUBSCRIPTION_ID)

provider "azurerm" {
  # Registers the resource providers this stack needs (ContainerService,
  # ContainerRegistry, OperationalInsights, PolicyInsights, ...).
  resource_provider_registrations = "extended"

  features {
    resource_group {
      # Dev and staging can be torn down with `terraform destroy`; prod cannot
      # delete a resource group that still holds resources.
      prevent_deletion_if_contains_resources = var.environment == "prod"
    }
  }
}
