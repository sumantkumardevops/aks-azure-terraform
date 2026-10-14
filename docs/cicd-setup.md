# CI/CD setup (GitHub Actions + Azure OIDC)

The workflows authenticate to Azure with **OpenID Connect**, so no client secret is stored in GitHub. GitHub
mints a short-lived token per run, and Entra ID trusts it only for the repository and contexts you list below.

| Workflow | Trigger | What it does |
|---|---|---|
| `terraform.yml` | pull request | fmt, validate, TFLint, Trivy scan, then `terraform plan` for dev, staging and prod (posted as PR comments) |
| `terraform.yml` | push to `main` | validate, then apply dev, then staging, then prod (each gated by its GitHub Environment) |
| `terraform.yml` | manual run | plan and apply one chosen environment |
| `drift.yml` | nightly | `terraform plan -detailed-exitcode` per environment; fails if the plan is not empty |
| `apply.yml` | called by `terraform.yml` | reusable plan + apply for one environment |

## 1. Bootstrap the remote state

```bash
az login
make bootstrap
```

Note the `TFSTATE_RG` and `TFSTATE_SA` values it prints.

## 2. Create the Entra ID app and federated credentials

Replace the first three variables, then run the block.

```bash
GITHUB_REPO="YOUR_GITHUB_USERNAME/azure-aks-terraform-platform"
STATE_RG="rg-tfstate-aksplat"
STATE_SA="tfstateXXXXXXXXXXXX"          # printed by make bootstrap

SUBSCRIPTION_ID="$(az account show --query id -o tsv)"
TENANT_ID="$(az account show --query tenantId -o tsv)"

APP_ID="$(az ad app create --display-name "github-aks-terraform-platform" --query appId -o tsv)"
az ad sp create --id "$APP_ID" >/dev/null

# One federated credential per GitHub context that needs Azure access:
#   pull_request            -> plan jobs on pull requests
#   ref:refs/heads/main     -> nightly drift detection
#   environment:<name>      -> apply jobs (one per GitHub Environment)
for entry in \
  "pr:pull_request" \
  "main:ref:refs/heads/main" \
  "env-dev:environment:dev" \
  "env-staging:environment:staging" \
  "env-prod:environment:prod"; do
  name="${entry%%:*}"
  subject="repo:${GITHUB_REPO}:${entry#*:}"
  az ad app federated-credential create --id "$APP_ID" --parameters "{
    \"name\": \"github-${name}\",
    \"issuer\": \"https://token.actions.githubusercontent.com\",
    \"subject\": \"${subject}\",
    \"audiences\": [\"api://AzureADTokenExchange\"]
  }"
done
```

## 3. Grant the app access

```bash
SCOPE="/subscriptions/${SUBSCRIPTION_ID}"

# Create and manage resources
az role assignment create --assignee "$APP_ID" --role "Contributor" --scope "$SCOPE"

# Terraform creates role assignments, policy assignments and locks, which
# Contributor cannot do (Microsoft.Authorization/*/write is excluded).
az role assignment create --assignee "$APP_ID" --role "User Access Administrator" --scope "$SCOPE"

# Read and write the Terraform state blobs (the account has shared keys disabled)
az role assignment create --assignee "$APP_ID" --role "Storage Blob Data Contributor" \
  --scope "$(az storage account show --name "$STATE_SA" --resource-group "$STATE_RG" --query id -o tsv)"
```

For a real organisation, scope these to a dedicated subscription (or resource groups) per environment and
constrain *User Access Administrator* with role-assignment conditions instead of granting it broadly.

## 4. Configure GitHub

Repository variables (Settings, Secrets and variables, Actions, Variables). These are identifiers, not secrets.

```bash
gh variable set AZURE_CLIENT_ID       --body "$APP_ID"
gh variable set AZURE_TENANT_ID       --body "$TENANT_ID"
gh variable set AZURE_SUBSCRIPTION_ID --body "$SUBSCRIPTION_ID"
gh variable set TFSTATE_RG            --body "$STATE_RG"
gh variable set TFSTATE_SA            --body "$STATE_SA"
```

Create the three GitHub Environments the apply jobs use:

```bash
for env in dev staging prod; do
  gh api --method PUT "repos/${GITHUB_REPO}/environments/${env}" >/dev/null
done
```

Then, in the GitHub UI (Settings, Environments), add **required reviewers** to `prod` (and optionally `staging`)
so a human approves before those applies start. Also enable branch protection on `main` and require the
`validate` and `plan` checks to pass.

## 5. Turn on drift detection (after the first deploy)

```bash
gh variable set ENABLE_DRIFT_DETECTION --body "true"
```

## Hardening ideas

* Pin third-party actions to full commit SHAs and let Dependabot update them.
* Set `exit-code: "1"` on the Trivy step once the baseline findings are triaged.
* Use a separate subscription and Entra app per environment, with the subscription ID stored as an
  environment-level variable.
