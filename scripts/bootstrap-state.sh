#!/usr/bin/env bash
#
# Creates the Azure Storage account that holds Terraform remote state, and
# writes backends/backend.hcl. Safe to run more than once.
#
# Usage:
#   az login
#   ./scripts/bootstrap-state.sh
#
# Optional environment variables:
#   LOCATION                     Azure region               (default: centralindia)
#   STATE_RG                     Resource group             (default: rg-tfstate-aksplat)
#   STATE_SA                     Storage account name       (default: derived from subscription ID)
#   STATE_CONTAINER              Blob container             (default: tfstate)
#   STATE_ADMIN_OBJECT_ID        Object ID to grant Storage Blob Data Contributor
#                                (default: the signed-in user)
#   STATE_ADMIN_PRINCIPAL_TYPE   User | ServicePrincipal | Group (default: User)

set -euo pipefail

LOCATION="${LOCATION:-centralindia}"
STATE_RG="${STATE_RG:-rg-tfstate-aksplat}"
STATE_CONTAINER="${STATE_CONTAINER:-tfstate}"
STATE_ADMIN_PRINCIPAL_TYPE="${STATE_ADMIN_PRINCIPAL_TYPE:-User}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v az >/dev/null 2>&1; then
  echo "Azure CLI (az) is not installed." >&2
  exit 1
fi

if ! az account show >/dev/null 2>&1; then
  echo "You are not logged in. Run 'az login' first." >&2
  exit 1
fi

sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum | cut -d' ' -f1
  else
    shasum -a 256 | cut -d' ' -f1
  fi
}

SUBSCRIPTION_ID="$(az account show --query id -o tsv)"
TENANT_ID="$(az account show --query tenantId -o tsv)"

# Storage account names are global, 3-24 chars, lowercase alphanumeric.
# Deriving the name from the subscription ID keeps the script idempotent.
STATE_SA="${STATE_SA:-tfstate$(printf '%s' "$SUBSCRIPTION_ID" | sha256 | cut -c1-12)}"

echo "Subscription : $SUBSCRIPTION_ID"
echo "Region       : $LOCATION"
echo "Resource grp : $STATE_RG"
echo "Storage acct : $STATE_SA"
echo "Container    : $STATE_CONTAINER"
echo

echo "==> Resource group"
az group create \
  --name "$STATE_RG" \
  --location "$LOCATION" \
  --tags purpose=terraform-state managed_by=bootstrap-script \
  --output none

echo "==> Storage account"
if ! az storage account show --name "$STATE_SA" --resource-group "$STATE_RG" >/dev/null 2>&1; then
  az storage account create \
    --name "$STATE_SA" \
    --resource-group "$STATE_RG" \
    --location "$LOCATION" \
    --sku Standard_GRS \
    --kind StorageV2 \
    --min-tls-version TLS1_2 \
    --allow-blob-public-access false \
    --allow-shared-key-access false \
    --tags purpose=terraform-state \
    --output none
else
  echo "Already exists, skipping creation."
fi

echo "==> Blob versioning and soft delete (recover from a bad state write)"
az storage account blob-service-properties update \
  --account-name "$STATE_SA" \
  --resource-group "$STATE_RG" \
  --enable-versioning true \
  --enable-delete-retention true \
  --delete-retention-days 14 \
  --output none

echo "==> Data-plane access (shared keys are disabled, so Entra ID RBAC is used)"
SA_ID="$(az storage account show --name "$STATE_SA" --resource-group "$STATE_RG" --query id -o tsv)"
PRINCIPAL_ID="${STATE_ADMIN_OBJECT_ID:-$(az ad signed-in-user show --query id -o tsv 2>/dev/null || true)}"

if [[ -z "$PRINCIPAL_ID" ]]; then
  echo "Could not determine your object ID (are you logged in as a service principal?)." >&2
  echo "Set STATE_ADMIN_OBJECT_ID and STATE_ADMIN_PRINCIPAL_TYPE, then re-run." >&2
  exit 1
fi

EXISTING="$(az role assignment list \
  --assignee "$PRINCIPAL_ID" \
  --role "Storage Blob Data Contributor" \
  --scope "$SA_ID" \
  --query "[0].id" -o tsv 2>/dev/null || true)"

if [[ -z "$EXISTING" ]]; then
  az role assignment create \
    --assignee-object-id "$PRINCIPAL_ID" \
    --assignee-principal-type "$STATE_ADMIN_PRINCIPAL_TYPE" \
    --role "Storage Blob Data Contributor" \
    --scope "$SA_ID" \
    --output none
else
  echo "Role assignment already exists."
fi

echo "==> Blob container (retrying while the role assignment propagates)"
created=0
for attempt in $(seq 1 12); do
  if az storage container create \
      --name "$STATE_CONTAINER" \
      --account-name "$STATE_SA" \
      --auth-mode login \
      --output none 2>/dev/null; then
    created=1
    break
  fi
  echo "  waiting for RBAC to propagate (${attempt}/12)..."
  sleep 15
done

if [[ "$created" -ne 1 ]]; then
  echo "Failed to create the container. Check your permissions on $STATE_SA and re-run." >&2
  exit 1
fi

echo "==> Writing backends/backend.hcl"
mkdir -p "$ROOT_DIR/backends"
cat > "$ROOT_DIR/backends/backend.hcl" <<EOF
resource_group_name  = "$STATE_RG"
storage_account_name = "$STATE_SA"
container_name       = "$STATE_CONTAINER"
use_azuread_auth     = true
EOF

cat <<EOF

Done. Next steps:

  export ARM_SUBSCRIPTION_ID="$SUBSCRIPTION_ID"
  make init plan ENV=dev

For GitHub Actions, set these repository variables (see docs/cicd-setup.md):

  AZURE_TENANT_ID       = $TENANT_ID
  AZURE_SUBSCRIPTION_ID = $SUBSCRIPTION_ID
  TFSTATE_RG            = $STATE_RG
  TFSTATE_SA            = $STATE_SA
EOF
