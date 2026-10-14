SHELL := /bin/bash

# Usage: make plan ENV=dev | staging | prod
ENV        ?= dev
VAR_FILE   := envs/$(ENV).tfvars
PLAN_FILE  := tfplan-$(ENV)
STATE_KEY  := aks-platform/$(ENV).tfstate

.DEFAULT_GOAL := help
.PHONY: help bootstrap check-env init fmt validate lint plan apply destroy output credentials

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-12s %s\n", $$1, $$2}'
	@echo
	@echo "Pick an environment with ENV=dev|staging|prod (default: dev)."

bootstrap: ## Create the remote state storage account (run once)
	./scripts/bootstrap-state.sh

check-env:
	@test -f $(VAR_FILE) || { echo "Unknown environment '$(ENV)': $(VAR_FILE) not found"; exit 1; }
	@test -f backends/backend.hcl || { echo "backends/backend.hcl missing. Run 'make bootstrap' first."; exit 1; }
	@test -n "$$ARM_SUBSCRIPTION_ID" || { echo "ARM_SUBSCRIPTION_ID is not set (export ARM_SUBSCRIPTION_ID=<id>)"; exit 1; }

init: check-env ## Initialise Terraform against the state key of ENV
	terraform init -input=false -reconfigure \
		-backend-config=backends/backend.hcl \
		-backend-config="key=$(STATE_KEY)"

fmt: ## Format all Terraform files
	terraform fmt -recursive

validate: ## Validate the configuration (no backend needed)
	terraform init -backend=false -input=false
	terraform validate

lint: ## Run tflint
	tflint --init
	tflint --recursive

plan: init ## Show what would change in ENV
	terraform plan -input=false -var-file=$(VAR_FILE) -out=$(PLAN_FILE)

apply: ## Apply the saved plan for ENV (run `make plan` first)
	@test -f $(PLAN_FILE) || { echo "No saved plan. Run 'make plan ENV=$(ENV)' first."; exit 1; }
	terraform apply -input=false $(PLAN_FILE)

destroy: init ## Destroy everything in ENV (asks for confirmation)
	terraform destroy -var-file=$(VAR_FILE)

output: init ## Show outputs of ENV
	terraform output

credentials: init ## Fetch kubeconfig for ENV (ADMIN=1 uses the local admin account)
	$$(terraform output -raw get_credentials_command) $(if $(ADMIN),--admin,)
