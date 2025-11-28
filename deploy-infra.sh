#!/usr/bin/env bash
# Deploys the AKS/ACR stack defined in bicep/main.bicep using Azure CLI.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./deploy.sh -p <projectName> [-e <environment>] [-l <location>] [-s <subscriptionId>] [-n <deploymentName>]

Parameters:
  -p  Project name (required)
  -e  Environment (default: dev)
  -l  Location for deployment (default: westeurope)
  -s  Subscription ID or name to target (optional; uses current if omitted)
  -n  Deployment name (default: project-environment-YYYYMMDDHHMMSS)
EOF
}

project=""
environment="dev"
location="westeurope"
subscription=""
deploymentName=""

while getopts ":p:e:l:s:n:h" opt; do
  case "${opt}" in
    p) project="${OPTARG}" ;;
    e) environment="${OPTARG}" ;;
    l) location="${OPTARG}" ;;
    s) subscription="${OPTARG}" ;;
    n) deploymentName="${OPTARG}" ;;
    h) usage; exit 0 ;;
        *) usage; exit 1 ;;
  esac
done

if [[ -z "${project}" ]]; then
  echo "Error: project name (-p) is required." >&2
  usage
  exit 1
fi

if [[ -z "${deploymentName}" ]]; then
  timestamp="$(date +"%Y%m%d%H%M%S")"
  deploymentName="${project}-${environment}-${timestamp}"
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

template="bicep/main.bicep"
if [[ ! -f "${template}" ]]; then
  echo "Template not found at ${template}" >&2
  exit 1
fi

echo "Deploying ${template}..."
az deployment sub create \
  --name "${deploymentName}" \
  --location "${location}" \
  --template-file "${template}" \
  --parameters projectName="${project}" environment="${environment}" location="${location}"

echo "Deployment complete."
