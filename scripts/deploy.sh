#!/usr/bin/env bash
set -euo pipefail

RESOURCE_GROUP="${RESOURCE_GROUP:-zt-demo-rg}"
LOCATION="${LOCATION:-eastus}"
ENV_NAME="${ENV_NAME:-zt-demo}"

echo "==> Getting your public IP..."
MY_IP=$(curl -s https://ifconfig.me)
echo "    Allowed IP: $MY_IP"

echo "==> Creating resource group: $RESOURCE_GROUP"
az group create \
  --name "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --output none

echo "==> Deploying Bicep templates..."
DEPLOY_OUTPUT=$(az deployment group create \
  --resource-group "$RESOURCE_GROUP" \
  --template-file infra/main.bicep \
  --parameters \
      envName="$ENV_NAME" \
      location="$LOCATION" \
      allowedIpAddress="$MY_IP" \
  --query "properties.outputs" \
  --output json)

FUNCTION_URL=$(echo "$DEPLOY_OUTPUT" | python3 -c "import sys,json; print(json.load(sys.stdin)['functionAppUrl']['value'])")
FUNC_APP_NAME=$(az functionapp list --resource-group "$RESOURCE_GROUP" --query "[0].name" -o tsv)

echo "==> Deploying Function App code..."
cd app/api
func azure functionapp publish "$FUNC_APP_NAME" --python
cd ../..

echo ""
echo "Deployment complete!"
echo "  Function App URL : $FUNCTION_URL"
echo "  Health check     : $FUNCTION_URL/api/health"
echo ""
echo "Run './scripts/teardown.sh' when done to avoid ongoing charges."
