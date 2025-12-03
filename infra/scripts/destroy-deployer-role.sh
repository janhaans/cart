#!/usr/bin/env bash
# Removes the App Registration, Service Principal, federated credential, and role assignments created for GitHub Actions.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./destroy-deployer-role.sh -c <clientId> [-g <resourceGroup>] [-s <subscriptionId>] [-y]

Required:
  -c  Application (client) ID of the App/Service Principal to delete

Optional:
  -g  Resource group to delete (default: cart-dev-rg)
  -s  Subscription ID or name (defaults to current)
  -y  Do not prompt for confirmation
EOF
}

clientId=""
resourceGroup="cart-dev-rg"
subscriptionId=""
assumeYes=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    -c) clientId="$2"; shift 2 ;;
    -g) resourceGroup="$2"; shift 2 ;;
    -s) subscriptionId="$2"; shift 2 ;;
    -y) assumeYes=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ -z "$clientId" ]]; then
  echo "Error: client ID (-c) is required." >&2
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

spObjectId="$(az ad sp show --id "$clientId" --query id -o tsv 2>/dev/null || true)"
if [[ -z "$spObjectId" ]]; then
  echo "Service principal not found for clientId: $clientId" >&2
  exit 1
fi

tenantId="$(az account show --query tenantId -o tsv)"

echo "About to remove role assignments, service principal, app, and resource group:"
echo "  Client ID:   $clientId"
echo "  SP ObjectId: $spObjectId"
echo "  Tenant ID:   $tenantId"
echo "  Resource RG: $resourceGroup"

if [[ "$assumeYes" != true ]]; then
  read -r -p "Proceed? [y/N] " reply
  if [[ ! "$reply" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
  fi
fi

echo "Deleting role assignments..."
az role assignment delete \
    --assignee-object-id "$spObjectId" \
    --role "Owner" \
    --resource-group "$resourceGroup" >/dev/null || true

echo "Deleting service principal..."
az ad sp delete --id "$clientId" >/dev/null || true

echo "Deleting app registration..."
az ad app delete --id "$clientId" >/dev/null || true

echo "Deleting resource group (and contained resources): $resourceGroup ..."
az group delete --name "$resourceGroup" --yes --no-wait || true

# Delete AKS-managed MC_* resource group if present
mcGroups=$(az group list --query "[?starts_with(name, 'MC_${resourceGroup}_')].name" -o tsv || true)
if [[ -n "$mcGroups" ]]; then
  while IFS= read -r mcRg; do
    [[ -z "$mcRg" ]] && continue
    echo "Deleting AKS-managed resource group: $mcRg ..."
    az group delete --name "$mcRg" --yes --no-wait || true
  done <<< "$mcGroups"
else
  echo "No AKS-managed MC_${resourceGroup}_* resource group found."
fi

echo "Done."
