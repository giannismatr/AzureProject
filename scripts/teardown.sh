#!/usr/bin/env bash
set -euo pipefail

RESOURCE_GROUP="${RESOURCE_GROUP:-zt-demo-rg}"

echo "==> WARNING: This will delete all resources in '$RESOURCE_GROUP'."
read -p "    Type the resource group name to confirm: " CONFIRM

if [ "$CONFIRM" != "$RESOURCE_GROUP" ]; then
  echo "Aborted."
  exit 1
fi

echo "==> Deleting resource group '$RESOURCE_GROUP'..."
az group delete --name "$RESOURCE_GROUP" --yes --no-wait
echo "    Deletion queued. Resources will be gone within a few minutes."
echo "    Cost: $0.00 after this point."
