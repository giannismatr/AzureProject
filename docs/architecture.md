# Architecture Diagrams

---

## 1. Overall Architecture

```mermaid
graph TB
    subgraph Internet["🌐 Public Internet"]
        USER["👤 You / Client"]
    end

    subgraph AAD["Azure Active Directory (Entra ID)"]
        IDENTITY["Managed Identity Token Service"]
    end

    subgraph RG["Azure Resource Group"]
        subgraph VNET["Virtual Network  10.0.0.0/16"]
            subgraph APP_SUBNET["App Subnet  10.0.1.0/24"]
                FUNC["⚡ Function App\n(Python)"]
                APP_NSG["🛡️ NSG\nAllow: HTTPS from your IP\nDeny: everything else"]
            end

            subgraph PE_SUBNET["Private Endpoint Subnet  10.0.2.0/24"]
                PE_KV["🔒 Private Endpoint\n→ Key Vault"]
                PE_BLOB["📦 Private Endpoint\n→ Blob Storage"]
                PE_NSG["🛡️ NSG\nAllow: VNet only\nDeny: everything else"]
            end
        end

        subgraph PaaS["PaaS Services (No Public Access)"]
            KV["🗝️ Key Vault\npublicNetworkAccess: Disabled"]
            STORAGE["💾 Blob Storage\npublicNetworkAccess: Disabled"]
        end

        LOGS["📊 Log Analytics\nWorkspace"]
    end

    USER -->|"HTTPS (port 443)"| APP_NSG
    APP_NSG --> FUNC
    FUNC -->|"Get token (no password)"| IDENTITY
    IDENTITY -->|"JWT token"| FUNC
    FUNC -->|"Private DNS resolves to\n10.0.2.x"| PE_KV
    FUNC -->|"Private DNS resolves to\n10.0.2.x"| PE_BLOB
    PE_KV --> KV
    PE_BLOB --> STORAGE
    KV -->|"AuditEvent logs"| LOGS
    STORAGE -->|"Transaction metrics"| LOGS
    FUNC -->|"Function App logs"| LOGS

    style Internet fill:#ffebeb
    style AAD fill:#e8f4fd
    style RG fill:#f0f8e8
    style VNET fill:#e8f0f8
    style APP_SUBNET fill:#d4e8d4
    style PE_SUBNET fill:#d4d4e8
    style PaaS fill:#f8f4e8
```

---

## 2. Request Flow — Reading a Secret

Step-by-step what happens when you call `GET /api/secret/my-api-key`:

```mermaid
sequenceDiagram
    actor User
    participant NSG as 🛡️ NSG
    participant Func as ⚡ Function App
    participant AAD as 🔐 Azure AD
    participant DNS as 🌐 Private DNS
    participant KV as 🗝️ Key Vault
    participant Logs as 📊 Log Analytics

    User->>NSG: HTTPS GET /api/secret/my-api-key
    NSG->>NSG: Check rules:<br/>Is port 443? ✓<br/>Is source IP allowed? ✓
    NSG->>Func: Forward request

    Func->>AAD: Request token for Key Vault<br/>(using Managed Identity — no password)
    AAD->>AAD: Verify identity exists<br/>Check RBAC: has Key Vault Secrets User? ✓
    AAD-->>Func: Return JWT access token

    Func->>DNS: Resolve <kv-name>.vault.azure.net
    DNS-->>Func: Returns 10.0.2.x (private IP)<br/>NOT the public internet IP

    Func->>KV: GET secret/my-api-key<br/>Authorization: Bearer <JWT>
    KV->>KV: Validate token ✓<br/>Check RBAC ✓<br/>Return secret value

    KV->>Logs: Write AuditEvent<br/>(who accessed what, when)
    KV-->>Func: Secret value

    Func-->>User: HTTP 200 { "value": "..." }
```

---

## 3. Network Security — NSG Rule Evaluation

NSG rules are evaluated **lowest priority number first**. First match wins.

```mermaid
flowchart TD
    REQ["📨 Inbound Request"] --> R100

    subgraph APP_NSG["App Subnet NSG — Rule Evaluation"]
        R100{"Priority 100\nPort 443?\nSource = your IP?"}
        R200{"Priority 200\nSource = VirtualNetwork?"}
        R4096["Priority 4096\nDeny All ❌"]
        ALLOW1["✅ Allow"]
        ALLOW2["✅ Allow"]
    end

    R100 -->|"Yes"| ALLOW1
    R100 -->|"No"| R200
    R200 -->|"Yes"| ALLOW2
    R200 -->|"No"| R4096

    style R4096 fill:#ffcccc
    style ALLOW1 fill:#ccffcc
    style ALLOW2 fill:#ccffcc
```

---

## 4. Zero Trust Principles Mapping

```mermaid
mindmap
  root((Zero Trust))
    Verify Explicitly
      Azure AD Managed Identity
        No passwords anywhere
        Automatic token rotation
        JWT on every request
      Function App key required
        All HTTP endpoints need ?code=
    Least Privilege
      Key Vault Secrets User
        Read secrets only
        Cannot create or delete
      Storage Blob Data Reader
        Read blobs only
        Cannot write or delete
      RBAC scoped to Resource Group
        Not subscription-wide
    Assume Breach
      NSG deny-all default
        Explicit allow rules only
        Your IP whitelisted
      Private Endpoints
        No public internet to PaaS
        Traffic stays in VNet
      All access logged
        Key Vault AuditEvent
        Function App logs
        Storage metrics
      Soft delete on Key Vault
        7-day recovery window
      TLS 1.2 minimum everywhere
```

---

## 5. Private Endpoint DNS Resolution

How the Function App reaches Key Vault without going through the public internet:

```mermaid
flowchart LR
    subgraph Without["❌ Without Private Endpoint"]
        FUNC1["Function App"] -->|"Resolves to\n40.x.x.x (public)"| PUB["Public Internet"] --> KV1["Key Vault\n(public endpoint)"]
    end

    subgraph With["✅ With Private Endpoint"]
        FUNC2["Function App"] -->|"DNS query:\n<kv>.vault.azure.net"| DNS["Private DNS Zone\nprivatelink.vaultcore.azure.net"]
        DNS -->|"Returns: 10.0.2.4\n(private IP)"| PE["Private Endpoint\n10.0.2.4"]
        PE --> KV2["Key Vault\n(no public access)"]
    end

    style Without fill:#fff0f0
    style With fill:#f0fff0
```

---

## 6. Managed Identity — No Passwords Flow

```mermaid
sequenceDiagram
    participant Dev as 👨‍💻 Developer
    participant Code as 📄 Code
    participant MI as 🪪 Managed Identity
    participant AAD as 🔐 Azure AD
    participant KV as 🗝️ Key Vault

    Note over Dev,KV: Traditional approach (BAD ❌)
    Dev->>Code: Hard-code connection string<br/>SECRET_KEY=abc123
    Code->>KV: Authenticate with secret key

    Note over Dev,KV: Zero Trust approach (GOOD ✅)
    Dev->>Code: Write ManagedIdentityCredential()
    Note over MI: Azure manages this identity<br/>No password ever created
    Code->>MI: Request token
    MI->>AAD: "I am Function App X, give me a token"
    AAD->>AAD: Verify identity ✓<br/>Check RBAC roles ✓
    AAD-->>MI: JWT token (expires in 1h)
    MI-->>Code: Token
    Code->>KV: GET secret (Bearer token)
    KV-->>Code: Secret value ✓
```

---

## 7. Bicep Module Dependency Graph

How the Bicep templates depend on each other:

```mermaid
graph TD
    MAIN["main.bicep\n(entry point)"]

    MAIN --> NET["network.bicep"]
    MAIN --> MON["monitoring.bicep"]
    MAIN --> KV["keyvault.bicep"]
    MAIN --> STOR["storage.bicep"]
    MAIN --> APP["app.bicep"]

    NET -->|"outputs:\nappSubnetId\npeSubnetId\nvnetId"| KV
    NET -->|"outputs:\nappSubnetId\npeSubnetId\nvnetId"| STOR
    NET -->|"outputs:\nappSubnetId"| APP

    MON -->|"outputs:\nworkspaceId"| KV
    MON -->|"outputs:\nworkspaceId"| STOR
    MON -->|"outputs:\nworkspaceId"| APP

    KV -->|"outputs:\nkeyVaultName"| APP
    STOR -->|"outputs:\nstorageAccountName"| APP

    style MAIN fill:#4a90d9,color:#fff
    style NET fill:#7bc67e
    style MON fill:#f0a500,color:#fff
    style KV fill:#e05c5c,color:#fff
    style STOR fill:#9b59b6,color:#fff
    style APP fill:#2ecc71,color:#fff
```

---

## 8. Cost Breakdown

```mermaid
pie title Monthly Cost (~$15/month total)
    "Private Endpoint — Key Vault (~$7)" : 7
    "Private Endpoint — Blob Storage (~$7)" : 7
    "Blob Storage data (<$1)" : 0.5
    "Everything else (free tier)" : 0.5
```
