#!/usr/bin/env bash
# Creates a GitHub Actions App/Service Principal with a GitHub OIDC federated credential
# and assigns Owner role on the subscription.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./grant-deployer-role.sh -o <githubOrg> -r <githubRepo> [-b <branch>] [-l <location>] [-s <subscriptionId>] [-n <appDisplayName>] [-y]

Required:
  -o  GitHub organization/owner
  -r  GitHub repository name

Optional:
  -b  Git branch for federated credential subject (default: main)
  -s  Subscription ID or name (defaults to current)
  -n  App Registration display name (default: <org>-<repo>-gha-oidc)
  -y  Auto-confirm without prompt
EOF
}

githubOrg="janhaans"
githubRepo="cart"
branch="main"
subscriptionId=""
appDisplayName=""
assumeYes=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    -o) githubOrg="$2"; shift 2 ;;
    -r) githubRepo="$2"; shift 2 ;;
    -b) branch="$2"; shift 2 ;;
    -s) subscriptionId="$2"; shift 2 ;;
    -n) appDisplayName="$2"; shift 2 ;;
    -y) assumeYes=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ -z "$githubOrg" || -z "$githubRepo" ]]; then
  echo "Error: GitHub org (-o) and repo (-r) are required." >&2
  usage
  exit 1
fi

if ! command -v az >/dev/null 2>&1; then
  echo "Azure CLI is required but not installed." >&2
  exit 1
fi

if ! az account show >/dev/null 2>&1; then
  echo "Not logged in. Run 'az login' first." >&2
  exit 1
fi

if [[ -n "$subscriptionId" ]]; then
  az account set --subscription "$subscriptionId"
fi

tenantId="$(az account show --query tenantId -o tsv)"
subscriptionId="$(az account show --query id -o tsv)"

subject="repo:${githubOrg}/${githubRepo}:ref:refs/heads/${branch}"
appDisplayName="${appDisplayName:-${githubOrg}-${githubRepo}-gha-oidc}"

echo "About to create App Registration and federated credential:"
echo "  App display name:    $appDisplayName"
echo "  Tenant ID:           $tenantId"
echo "  Subscription ID:     $subscriptionId"
echo "  GitHub subject:      $subject"

if [[ "$assumeYes" != true ]]; then
  read -r -p "Proceed? [y/N] " reply
  if [[ ! "$reply" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
  fi
fi

echo "Creating App Registration..."
appId="$(az ad app create --display-name "$appDisplayName" --query appId -o tsv)"

echo "Creating Service Principal..."
spId="$(az ad sp create --id "$appId" --query id -o tsv)"

echo "Adding federated credential for GitHub Actions..."
az ad app federated-credential create --id "$appId" --parameters "{
  \"name\": \"github-oidc\",
  \"issuer\": \"https://token.actions.githubusercontent.com\",
  \"subject\": \"${subject}\",
  \"description\": \"GitHub Actions OIDC\",
  \"audiences\": [\"api://AzureADTokenExchange\"]
}"

echo "Assigning Owner on subscription $subscriptionId ..."
az role assignment create \
  --assignee-object-id "$spId" \
  --assignee-principal-type ServicePrincipal \
  --role "Owner" \
  --scope "/subscriptions/$subscriptionId" \
  >/dev/null

echo "Done."
echo "Use these in GitHub Actions secrets/vars:"
echo "  AZURE_OBJECT_ID=$spId"
echo "  AZURE_CLIENT_ID=$appId"
echo "  AZURE_TENANT_ID=$tenantId"
echo "  AZURE_SUBSCRIPTION_ID=$subscriptionId"
