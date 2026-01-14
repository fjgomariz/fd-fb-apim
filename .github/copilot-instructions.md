
# GitHub Copilot – Working Instructions for the Sample ‘Private-by-Default’ Web App on Azure

> **Purpose**: Use this file as the single source of truth to iteratively build a **minimal yet production-minded** sample with:
>
> - **React** frontend (container) → **Azure Front Door Premium (with WAF)** → **App Service for Containers** (private origin)
> - **FastAPI** backend (container) → **Azure API Management** (private origin, JWT validation, identity propagation) → **App Service for Containers** (private origin)
> - **Azure Blob Storage** (private endpoint) for file **upload** and **list**
> - End-to-end **Managed Identities**, **RBAC least privilege**, **Private Endpoints**/**Private Link**, **Application Insights** telemetry (user & guest tenant), and **GitHub Actions** with **OIDC federated credentials**
>
> **Audience**: You + GitHub Copilot. Copy/paste the prompts provided here into your IDE to scaffold code, Bicep modules, policies, and pipelines step by step.

---

## 0) Architecture Overview

```
[Browser]
   │  Entra ID (OIDC)
   ▼
Azure Front Door Premium (WAF)
   │  (Private Link origin)
   ▼
Frontend Web App (Linux, containers) ──► App Insights (client events)
   │                                  
   │  Auth: MSAL acquires token for backend API scope
   ▼
Azure API Management (internal + Private Endpoint)
   │  validate-jwt (issuer: Entra ID)  
   │  extract userId (oid) & guestTenantId (from `idp` claim)
   │  add headers: x-user-id, x-guest-tenant-id
   ▼
Backend Web App (Linux, containers, MSI)
   │
   │  MSI → Azure Blob Storage (private endpoint) via RBAC (Blob Data Contributor on container scope)
   ▼
Storage Account (Blob, private endpoint) ──► App Insights (server traces)
```

**Key claims**: 
- `oid` (object ID) → used as **UserId**
- `idp` (identity provider) contains the **home tenant** URL, e.g. `https://sts.windows.net/<GuestTenantId>/...` → parsed to **GuestTenantId**

> **Note**: This sample assumes **B2B guest** users sign in with their **corporate accounts**. No self-sign-up. Tokens are validated in APIM and required by the backend.

---

## 1) Repository Layout

```
repo-root/
├─ infra/                          # Bicep modules + params
│  ├─ main.bicep                   # orchestrates modules
│  ├─ modules/
│  │  ├─ rg.bicep
│  │  ├─ acr.bicep
│  │  ├─ appservice-plan.bicep
│  │  ├─ webapp.bicep              # generic container web app module
│  │  ├─ apim.bicep
│  │  ├─ storage.bicep
│  │  ├─ frontdoor.bicep           # + WAF + origins with Private Link
│  │  ├─ private-endpoints.bicep
│  │  ├─ app-insights.bicep
│  │  ├─ log-analytics.bicep
│  │  └─ keyvault.bicep
│  └─ parameters/
│     └─ main.parameters.json
│
├─ src/
│  ├─ frontend/                    # React app
│  │  ├─ Dockerfile
│  │  └─ src/...                   
│  └─ backend/                     # FastAPI app
│     ├─ Dockerfile
│     └─ app/
│        ├─ main.py
│        └─ storage.py
│
├─ apim/
│  ├─ policies/
│  │  ├─ global.xml
│  │  └─ backend-api.xml           # validate-jwt + header enrichment
│  └─ api-definition.yaml          # OpenAPI (for import)
│
├─ .github/
│  └─ workflows/
│     ├─ deploy-infra.yml
│     ├─ build-and-deploy-frontend.yml
│     └─ build-and-deploy-backend.yml
│
├─ copilot-instructions.md         # this file
└─ README.md
```

---

## 2) Prerequisites

- Azure subscription + permissions to create resources
- Microsoft Entra ID tenant admin/delegated permissions to:
  - Create **App Registrations** (SPA & Web API) and **Service Principals**
  - Add **token configuration** (optional claims, expose API scopes)
  - Configure **federated credentials** for GitHub OIDC on a **deployment SP**
- GitHub repository with Actions enabled
- Local tooling: `az`, `bicep`, `docker`, `gh`, `jq`, `make` (optional), `node`, `python3`

> ⚠️ **Cost note**: Front Door Premium and APIM incur non-trivial costs. For demos, consider APIM **Developer** tier. For production, evaluate Premium.

---

## 3) Naming & Inputs (environment variables)

Define once in your shell (or GitHub Actions secrets):

```bash
export AZ_SUBSCRIPTION_ID="<subscription-guid>"
export AZ_TENANT_ID="<tenant-guid>"
export AZ_LOCATION="westeurope"
export AZ_RESOURCE_GROUP="rg-sample-privapp-weu"
export AZ_ENV="dev"

# App names (must be globally unique where applicable)
export AZ_ACR_NAME="acrprivappweu"
export AZ_FRONTEND_APP="weu-privapp-frontend"
export AZ_BACKEND_APP="weu-privapp-backend"
export AZ_STORAGE_NAME="stprivappweu"
export AZ_APPINSIGHTS_NAME="appi-privapp-weu"
export AZ_LAW_NAME="law-privapp-weu"
export AZ_APIM_NAME="apim-privapp-weu"
export AZ_FD_PROFILE="fd-privapp-weu"
export AZ_KV_NAME="kv-privapp-weu"

# Entra ID app registrations
export ENTRA_APP_FRONTEND_CLIENT_ID="<guid-after-create>"
export ENTRA_APP_API_CLIENT_ID="<guid-after-create>"
export ENTRA_APP_API_SCOPE="api://$ENTRA_APP_API_CLIENT_ID/files.access"
```

---

## 4) Backlog – Build with GitHub Copilot (each task has prompts & acceptance criteria)

> Work item by work item. Paste the **Prompts for Copilot** into your IDE as you go.

### T1 – Initialize repo & scaffolding
**Goal**: Baseline repo with folders, `.gitignore`, `README.md` and this file.

**Prompt for Copilot**:
> *Create the folder structure shown in the repo layout above and minimal placeholder files. Add a root README with the project summary and a checklist of tasks.*

**Acceptance**:
- Folder tree exists
- Linting scripts and Prettier/Black optional

---

### T2 – Bicep modules (infrastructure as code)
**Goal**: Modular Bicep including ACR, App Service plan, two Web Apps (Linux containers, system-assigned MSI), Storage (Blob), APIM (internal/Private Endpoint), Front Door Premium (WAF + Private Link origins), Key Vault, App Insights + Log Analytics, and necessary **Private Endpoints**.

**Prompts for Copilot** (use in `infra/modules`):
1. *Generate a `webapp.bicep` module that creates a Linux Web App for Containers with system-assigned identity, container settings (image name/tag and ACR), app settings, VNet integration optional, and outputs the hostname and identity principalId.*
2. *Generate a `apim.bicep` module that creates API Management (Developer/Premium as param), enables Application Insights, private endpoint, and outputs gateway URL and resource IDs.*
3. *Generate a `frontdoor.bicep` module for Front Door Premium with a WAF policy (managed rules + custom blocklist), origin groups for `frontend` and `apim`, each using **Private Link** to the respective private endpoints. Expose a single `https` route `/` to frontend and `/api/*` to APIM.*
4. *Generate `storage.bicep` with Blob service + a container `uploads`, soft delete, and a private endpoint.*
5. *Generate `private-endpoints.bicep` to create PEs for: frontend web app, backend web app (if needed), APIM, and Storage Blob; include private DNS zones and links.*
6. *Generate `app-insights.bicep` + `log-analytics.bicep` and wire AI to Web Apps/APIM.*
7. *Create `main.bicep` to orchestrate all modules with parameters and outputs.*

**Acceptance**:
- `infra/main.bicep` compiles (`bicep build` succeeds)
- All modules parameterized (names, SKUs, locations)

---

### T3 – Entra ID app registrations (SPA + Web API)
**Goal**: SPA (frontend) obtains ID token + API access token; Web API exposes scope; no self-service sign-up; only invited users.

**Prompts for Copilot**:
- *Write an `az` script to create the **API app registration**, expose scope `files.access`, and create the **frontend app registration** pre-authorized to request that scope. Configure ID token claims to include `oid` and `idp`.*
- *Add notes to parse `GuestTenantId` from the `idp` claim value like `https://sts.windows.net/<GUID>/...`.*

**Acceptance**:
- Two app registrations created; SPA has Client ID; API has Application (client) ID
- Scope `files.access` exists

**Example (script sketch)**:
```bash
# API app
API_APP_ID=$(az ad app create --display-name "privapp-api" --query appId -o tsv)
# expose scope
az ad app update --id $API_APP_ID --set api.oauth2PermissionScopes="[{
  \"adminConsentDescription\": \"Access files API\", 
  \"adminConsentDisplayName\": \"Access files API\", 
  \"id\": \"$(uuidgen)\", 
  \"isEnabled\": true, 
  \"type\": \"User\", 
  \"value\": \"files.access\"
}]"

# Frontend SPA
SPA_APP_ID=$(az ad app create --display-name "privapp-frontend" --query appId -o tsv)
# optional: pre-authorize SPA for API scope (requires service principal objects)
```

> Tip: In the **Token configuration** of both apps, add optional claim **`idp`** in **ID token** and **Access token**.

---

### T4 – GitHub OIDC federated credentials for CI/CD
**Goal**: Deploy infra & apps with **federated identity** (OIDC) – no shared secrets.

**Prompts for Copilot**:
- *Write an `az ad sp create-for-rbac` (or Graph-based) flow that creates a **deployment service principal**, grants **Contributor** on the resource group, and adds a **federated credential** for this repo with subject `repo:<org>/<repo>:environment:<env>`.*
- *Produce a snippet for `azure/login@v2` configuring client-id, tenant-id, subscription-id.*

**Acceptance**:
- Service principal exists
- Federated credential linked to GitHub environment

---

### T5 – GitHub Actions: deploy infrastructure
**Goal**: `deploy-infra.yml` that logs in with OIDC, runs `bicep what-if`, then `az deployment group create`.

**Prompt for Copilot**:
> *Create `.github/workflows/deploy-infra.yml` that: uses `azure/login@v2` with OIDC, runs `az bicep build`, validates with `what-if`, and deploys `infra/main.bicep` with parameter file. *

**Acceptance**:
- Workflow runs successfully and produces outputs

**Example (skeleton)**:
```yaml
name: Deploy Infra
on:
  workflow_dispatch:
  push:
    paths:
      - 'infra/**'

jobs:
  deploy:
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read
    steps:
      - uses: actions/checkout@v4
      - uses: azure/login@v2
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
      - name: What-if
        run: |
          az group create -n $AZ_RESOURCE_GROUP -l $AZ_LOCATION
          az deployment group what-if \
            -g $AZ_RESOURCE_GROUP \
            -f infra/main.bicep \
            -p @infra/parameters/main.parameters.json
      - name: Deploy
        run: |
          az deployment group create \
            -g $AZ_RESOURCE_GROUP \
            -f infra/main.bicep \
            -p @infra/parameters/main.parameters.json \
            --query properties.outputs
```

---

### T6 – Build & deploy containers (frontend + backend)
**Goal**: Two workflows to build/push to ACR and update Web Apps.

**Prompts for Copilot**:
- *Create `build-and-deploy-frontend.yml` that logs in to Azure & ACR, builds the React container, pushes to ACR, and updates the frontend Web App container configuration. Use the Front Door endpoint as PUBLIC_URL.*
- *Create `build-and-deploy-backend.yml` that builds the FastAPI container, pushes to ACR, and updates the backend Web App. No storage secrets—use MSI in code.*

**Acceptance**:
- Images in ACR; Web Apps updated; zero plaintext secrets in workflows

---

### T7 – APIM: Validate JWT, enrich headers, enforce presence
**Goal**: APIM policy that rejects unauthenticated calls and forwards enriched identity context.

**Prompt for Copilot** (place in `apim/policies/backend-api.xml`):
> *Write an APIM policy to `validate-jwt` against Entra ID, then set `x-user-id` from `oid` and `x-guest-tenant-id` by parsing the `idp` claim (extract GUID between `sts.windows.net/` and next `/`). If either is missing, return 401. Add `set-variable` for logging these values in Application Insights.*

**Acceptance**:
- Requests without valid token → 401
- Valid requests forwarded with headers to backend

**Example extraction snippet**:
```xml
<inbound>
  <validate-jwt header-name="Authorization" require-scheme="Bearer">
    <openid-config url="https://login.microsoftonline.com/${AZ_TENANT_ID}/v2.0/.well-known/openid-configuration" />
    <audiences>
      <audience>${ENTRA_APP_API_CLIENT_ID}</audience>
    </audiences>
  </validate-jwt>
  <set-variable name="userId" value="@(context.Principal?.GetClaimValue(\"oid\"))" />
  <set-variable name="idp" value="@(context.Principal?.GetClaimValue(\"idp\"))" />
  <set-variable name="guestTenantId" value="@{
      var idp = (string)context.Variables[\"idp\"]; 
      if (string.IsNullOrEmpty(idp)) return string.Empty; 
      var marker = \"sts.windows.net/\"; 
      var i = idp.IndexOf(marker); 
      if (i < 0) return string.Empty; 
      var start = i + marker.Length; 
      var end = idp.IndexOf('/', start); 
      return end > start ? idp.Substring(start, end - start) : idp.Substring(start);
  }" />
  <choose>
    <when condition="@(!context.Variables.ContainsKey(\"userId\") || string.IsNullOrEmpty((string)context.Variables[\"userId\"]) || string.IsNullOrEmpty((string)context.Variables[\"guestTenantId\"]))">
      <return-response>
        <set-status code="401" reason="Unauthorized" />
      </return-response>
    </when>
  </choose>
  <set-header name="x-user-id" exists-action="override">
    <value>@((string)context.Variables[\"userId\"]) </value>
  </set-header>
  <set-header name="x-guest-tenant-id" exists-action="override">
    <value>@((string)context.Variables[\"guestTenantId\"]) </value>
  </set-header>
  <base />
</inbound>
```

---

### T8 – Backend (FastAPI) – MSI to Blob
**Goal**: Endpoints `/files/upload` and `/files/list` using **DefaultAzureCredential** and App Setting for container name.

**Prompts for Copilot**:
- *Create `src/backend/app/main.py` FastAPI app with two endpoints: (1) `POST /files/upload` receives multipart file and uploads to Blob using MSI; (2) `GET /files/list` lists blobs. Read user context from headers `x-user-id` and `x-guest-tenant-id` and log them to Application Insights. Return 400 if missing.*
- *Create `src/backend/app/storage.py` helper with `azure-storage-blob` and `azure-identity`.*

**Acceptance**:
- Works locally with `az login` (for dev)
- Works in App Service via MSI; no keys used

**Code sketch**:
```python
from fastapi import FastAPI, File, UploadFile, HTTPException, Request
from azure.identity import DefaultAzureCredential
from azure.storage.blob import BlobServiceClient
import os

app = FastAPI()

credential = DefaultAzureCredential()
account_url = f"https://{os.environ['AZ_STORAGE_NAME']}.blob.core.windows.net"
container = os.environ.get('AZ_BLOB_CONTAINER', 'uploads')

bsc = BlobServiceClient(account_url, credential=credential)

@app.post('/files/upload')
async def upload(request: Request, file: UploadFile = File(...)):
    uid = request.headers.get('x-user-id')
    gtid = request.headers.get('x-guest-tenant-id')
    if not uid or not gtid:
        raise HTTPException(status_code=401, detail='Missing identity headers')
    blob = bsc.get_blob_client(container=container, blob=file.filename)
    await blob.upload_blob(await file.read(), overwrite=True)
    return {"name": file.filename}

@app.get('/files/list')
async def list_files(request: Request):
    uid = request.headers.get('x-user-id')
    gtid = request.headers.get('x-guest-tenant-id')
    if not uid or not gtid:
        raise HTTPException(status_code=401, detail='Missing identity headers')
    container_client = bsc.get_container_client(container)
    return [b.name for b in container_client.list_blobs()]
```

> **RBAC**: Assign the backend Web App’s **system-assigned MSI** role **Storage Blob Data Contributor** at **container** scope.

---

### T9 – Frontend (React) – MSAL + calls via Front Door
**Goal**: Authenticate with Entra ID, acquire token for API scope, call `/api/files/*` through Front Door.

**Prompts for Copilot**:
- *Scaffold a React app with MSAL React. Configure authority = `https://login.microsoftonline.com/<AZ_TENANT_ID>/`, clientId = `<ENTRA_APP_FRONTEND_CLIENT_ID>`, and request scope `<ENTRA_APP_API_SCOPE>`. Add two buttons: Upload file, List files.*
- *Use `fetch` to call `${FD_ENDPOINT}/api/files/...` passing `Authorization: Bearer <access_token>`.*

**Acceptance**:
- Sign-in works only for invited users
- List and upload work via Front Door → APIM → Backend

---

### T10 – WAF & security hardening
**Goal**: Baseline WAF rules and allowlist.

**Prompts for Copilot**:
- *Add managed rule set (OWASP) with anomaly scoring. Include a custom rule to block disallowed countries or IPs (param). Ensure HTTPS-only and HSTS. Add rate-limiting on `/api/*` routes.*

**Acceptance**:
- WAF policy attached to FD profile and route

---

### T11 – Observability
**Goal**: Application Insights logs with `userId` and `guestTenantId` correlated end-to-end.

**Prompts for Copilot**:
- *Enable `APPLICATIONINSIGHTS_CONNECTION_STRING` on both Web Apps.*
- *Add logging in backend to emit custom dimensions `{ userId, guestTenantId }`.*
- *Provide Kusto queries to verify requests per guest tenant and unique users.*

**Acceptance**:
- Queries return expected results

**KQL examples**:
```kusto
requests
| extend userId=tostring(customDimensions.userId), guestTenantId=tostring(customDimensions.guestTenantId)
| summarize count() by guestTenantId, userId
| order by count_ desc
```

---

### T12 – Private by default (validation)
**Goal**: Confirm no public access except Front Door.

**Checklist**:
- [ ] Web Apps **not** publicly reachable (origins are Private Link from FD)
- [ ] Storage account public access **disabled**; blob service via private endpoint only
- [ ] APIM gateway not internet-exposed (private endpoint); FD uses Private Link origin
- [ ] All inter-service calls use **Managed Identity**

---

## 5) Example: Parameters & minimal `main.parameters.json`

```json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "location": { "value": "westeurope" },
    "names": {
      "value": {
        "acr": "acrprivappweu",
        "frontendApp": "weu-privapp-frontend",
        "backendApp": "weu-privapp-backend",
        "storage": "stprivappweu",
        "apim": "apim-privapp-weu",
        "frontdoor": "fd-privapp-weu",
        "insights": "appi-privapp-weu",
        "law": "law-privapp-weu",
        "kv": "kv-privapp-weu"
      }
    }
  }
}
```

---

## 6) Troubleshooting quick wins

- **401 at APIM**: Check audience (API app’s client ID), token issuer (tenant), and APIM policy URL for OpenID config. Confirm `idp` optional claim is present; otherwise, add it in Token configuration.
- **Storage auth failures**: Ensure backend Web App MSI is assigned **Storage Blob Data Contributor** **at the container scope** and that code uses `DefaultAzureCredential`.
- **Origins not reachable**: Confirm **Private Link** origin health in Front Door, DNS zones linked, and PEs approved.
- **React token acquisition**: Check scope name matches `api://<API_CLIENT_ID>/files.access` and redirect URIs are configured for SPA.
- **GitHub OIDC login fails**: Verify federated credential subject/issuer matches workflow environment and `azure/login@v2` inputs.

---

## 7) Definition of Done (end-to-end)

- [ ] Frontend reachable only through **Front Door** (WAF enforced)
- [ ] Backend reachable only through **APIM** (APIM private origin via FD)
- [ ] Unauthenticated or malformed requests → **401** at APIM
- [ ] Upload & List work using **Managed Identity** (no keys)
- [ ] App Insights shows `userId` and `guestTenantId` flowing through
- [ ] All deploys from GitHub **without** stored secrets (OIDC)

---

## 8) Appendix – Helpful Copilot prompts (copy/paste)

- *Write a Bicep module for an Azure Storage Account with Blob service, container `uploads`, soft delete enabled, and a private endpoint + private DNS zones.*
- *Generate a Dockerfile for a FastAPI app running on Uvicorn, port 8080, non-root user, slim Python image, and health check.*
- *Produce MSAL React setup code with a protected component and an API call using an access token for scope `${ENTRA_APP_API_SCOPE}`.*
- *Write a GitHub Action that builds a Docker image, logs in to ACR using OIDC (no passwords), tags with SHA + date, pushes, and updates an App Service for Containers container image.*
- *Create APIM policy XML to validate a JWT, extract `oid` and parse `idp` to a GUID called `guestTenantId`, return 401 if missing, and forward them as headers.*

---

> **Security stance**: No connection strings or keys. Prefer **Managed Identity**, **RBAC**, **Private Link**, **WAF**, **minimal scopes**.

