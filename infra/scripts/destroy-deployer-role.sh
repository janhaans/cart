#!/usr/bin/env bash
# Removes the App Registration, Service Principal, federated credential, and role assignments created for GitHub Actions.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./destroy-deployer-role.sh -c <clientId> [-s <subscriptionId>] [-y]

Required:
  -c  Application (client) ID of the App/Service Principal to delete

Optional:
  -s  Subscription ID or name (defaults to current)
  -y  Do not prompt for confirmation
EOF
}

clientId=""
subscriptionId=""
assumeYes=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    -c) clientId="$2"; shift 2 ;;
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
else
  subscriptionId="$(az account show --query id -o tsv)"
fi

spObjectId="$(az ad sp show --id "$clientId" --query id -o tsv 2>/dev/null || true)"
if [[ -z "$spObjectId" ]]; then
  echo "Service principal not found for clientId: $clientId" >&2
  exit 1
fi

tenantId="$(az account show --query tenantId -o tsv)"

echo "About to remove role assignments, service principal and app:"
echo "  Client ID:   $clientId"
echo "  SP ObjectId: $spObjectId"
echo "  Tenant ID:   $tenantId"

if [[ "$assumeYes" != true ]]; then
  read -r -p "Proceed? [y/N] " reply
  if [[ ! "$reply" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
  fi
fi

echo "Deleting role assignments..."
assignments=$(az role assignment list --assignee "$spObjectId" --query "[].id" -o tsv || true)
if [[ -n "$assignments" ]]; then
  while IFS= read -r ra_id; do
    [[ -z "$ra_id" ]] && continue
    az role assignment delete --ids "$ra_id" >/dev/null || true
  done <<< "$assignments"
else
  echo "  No role assignments found for this principal."
fi

echo "Deleting service principal..."
az ad sp delete --id "$clientId" >/dev/null || true

echo "Deleting app registration..."
az ad app delete --id "$clientId" >/dev/null || true

echo "Done."
