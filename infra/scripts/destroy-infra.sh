#!/usr/bin/env bash
# Destroys the Azure infra created by deploy.sh (resource group + AKS node resource group).
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./destroy.sh -p <projectName> [-e <environment>] [-l <location>] [-s <subscriptionId>] [--keep-mc] [-y]

Parameters:
  -p  Project name (required)
  -e  Environment (default: dev)
  -l  Location (default: westeurope) used to derive AKS-managed MC_* resource group
  -s  Subscription ID or name to target (optional; uses current if omitted)
  --keep-mc  Do not delete the AKS-managed MC_* resource group (default: delete it)
  -y  Do not prompt for confirmation
EOF
}

project=""
environment="dev"
location="westeurope"
subscription=""
keep_mc=false
assume_yes=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    -p) project="$2"; shift 2 ;;
    -e) environment="$2"; shift 2 ;;
    -l) location="$2"; shift 2 ;;
    -s) subscription="$2"; shift 2 ;;
    --keep-mc) keep_mc=true; shift ;;
    -y) assume_yes=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ -z "${project}" ]]; then
  echo "Error: project name (-p) is required." >&2
  usage
  exit 1
fi

if ! command -v az >/dev/null 2>&1; then
  echo "Azure CLI (az) is required but not found in PATH." >&2
  exit 1
fi

# Ensure login
if ! az account show >/dev/null 2>&1; then
  echo "Not logged in. Running 'az login'..."
  az login >/dev/null
fi

# Set subscription if provided
if [[ -n "${subscription}" ]]; then
  echo "Setting subscription: ${subscription}"
  az account set --subscription "${subscription}"
fi

rgName="${project}-${environment}-rg"
baseName="$(echo "${project}-${environment}" | tr '[:upper:]' '[:lower:]')"
aksName="${baseName}-aks"
mcRgName="MC_${rgName}_${aksName}_${location}"

echo "Primary resource group: ${rgName}"
echo "AKS node resource group: ${mcRgName}"

if [[ "${assume_yes}" = false ]]; then
  read -r -p "Delete these resource groups? [y/N] " reply
  if [[ ! "${reply}" =~ ^[Yy]$ ]]; then
    echo "Aborting."
    exit 1
  fi
fi

echo "Deleting resource group ${rgName}..."
az group delete --name "${rgName}" --yes --no-wait

if [[ "${keep_mc}" = false ]]; then
  echo "Deleting AKS-managed resource group ${mcRgName}..."
  az group delete --name "${mcRgName}" --yes --no-wait
else
  echo "Skipping deletion of AKS-managed resource group ${mcRgName} (--keep-mc set)."
fi

echo "Deletion requests submitted. Monitor with: az group list --query \"[].{name:name, state:properties.provisioningState}\""
