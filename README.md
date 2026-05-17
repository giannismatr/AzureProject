# Zero Trust Network Demo — Azure

A working demonstration of Zero Trust networking principles on Azure, built with Bicep IaC and Azure Functions. Designed to be low-cost (~$1–3/month) and easy to tear down.

## Zero Trust Principles Demonstrated

| Principle | Implementation |
|---|---|
| **Verify explicitly** | Azure AD Managed Identity — every service call is authenticated |
| **Least privilege** | RBAC roles scoped to minimum required (`Key Vault Secrets User`, `Storage Blob Data Reader`) |
| **Assume breach** | NSGs deny all by default, Private Endpoints remove public internet access to PaaS, all access is logged |

## Architecture

```
Internet
    │  (HTTPS only, from your IP)
    ▼
Function App  ──── System-assigned Managed Identity
    │  (VNet-integrated, no public IP on PaaS)
    ▼
Private Endpoints (10.0.2.0/24)
    ├── Azure Key Vault      (audit logged)
    └── Azure Blob Storage   (no public access)
    │
    ▼
Log Analytics Workspace  (all access audited)
```

**Subnets:**
- `10.0.1.0/24` — app subnet (Function App VNet integration)
- `10.0.2.0/24` — private endpoint subnet (Key Vault, Blob Storage)

## Cost Estimate

| Resource | Monthly Cost |
|---|---|
| Private Endpoints (x2) | ~$14 |
| Blob Storage | <$1 |
| Function App (consumption) | Free tier |
| Log Analytics (5GB free) | $0 |
| VNet / NSGs | Free |
| **Total** | **~$15/month** |

> Tear down with `./scripts/teardown.sh` when not demoing — cost drops to $0.

## Prerequisites

- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli)
- [Azure Functions Core Tools](https://github.com/Azure/azure-functions-core-tools)
- An Azure subscription
- Python 3.11+

## Deploy

```bash
# Login to Azure
az login

# Set your subscription
az account set --subscription "<your-subscription-id>"

# Deploy everything
./scripts/deploy.sh
```

Environment variables (optional overrides):

```bash
RESOURCE_GROUP=my-rg LOCATION=westeurope ENV_NAME=my-demo ./scripts/deploy.sh
```

## Test

```bash
# Get your function key from the portal or:
FUNC_KEY=$(az functionapp keys list \
  --name <func-app-name> \
  --resource-group zt-demo-rg \
  --query "functionKeys.default" -o tsv)

FUNC_URL=https://<func-app-name>.azurewebsites.net \
FUNC_KEY=$FUNC_KEY \
./scripts/test.sh
```

## API Endpoints

| Method | Path | Description |
|---|---|---|
| GET | `/api/health` | Health check |
| GET | `/api/secret/{name}` | Read a Key Vault secret via Managed Identity |
| GET | `/api/blobs?container=demo` | List blobs via Managed Identity |
| POST | `/api/blobs/{name}?container=demo` | Upload a blob via Managed Identity |

## Tear Down

```bash
./scripts/teardown.sh
```

## Project Structure

```
.
├── infra/
│   ├── main.bicep          # Entry point — wires all modules together
│   ├── network.bicep       # VNet, subnets, NSGs (deny-all default)
│   ├── keyvault.bicep      # Key Vault + private endpoint + DNS zone
│   ├── storage.bicep       # Blob Storage + private endpoint + DNS zone
│   ├── app.bicep           # Function App + Managed Identity + RBAC
│   └── monitoring.bicep    # Log Analytics workspace
├── app/
│   └── api/
│       ├── function_app.py # Python Azure Functions (HTTP triggers)
│       ├── requirements.txt
│       └── host.json
├── scripts/
│   ├── deploy.sh           # One-command deploy
│   ├── teardown.sh         # Delete all resources
│   └── test.sh             # Smoke test all endpoints
└── README.md
```

## Key Security Decisions

- **No passwords anywhere** — Managed Identity handles all auth to Key Vault and Storage
- **No public endpoints on PaaS** — `publicNetworkAccess: Disabled` on Key Vault and Storage
- **NSG deny-all default** — explicit allow rules only for HTTPS from your IP
- **TLS 1.2 minimum** — enforced on all services
- **Soft delete on Key Vault** — 7-day recovery window
- **All access logged** — diagnostic settings ship to Log Analytics on every service
