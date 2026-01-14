# Private-by-Default Web App on Azure

A production-ready sample application demonstrating Azure security best practices with a private-by-default architecture.

## Architecture

This repository contains a **React** frontend and **FastAPI** backend application deployed on Azure with end-to-end security:

- **Frontend**: React SPA with MSAL authentication → Azure Front Door Premium (WAF) → App Service (private origin)
- **Backend**: FastAPI → Azure API Management (JWT validation, identity propagation) → App Service (private origin)
- **Storage**: Azure Blob Storage with private endpoints for file upload/list operations
- **Security**: Managed Identities, RBAC least privilege, Private Endpoints/Private Link, Application Insights telemetry
- **CI/CD**: GitHub Actions with OIDC federated credentials (no secrets)

## Key Features

- ✅ **Private by default** - No public endpoints except Front Door
- ✅ **Zero secrets** - Managed Identity for all Azure resource access
- ✅ **B2B Guest support** - Tracks both UserId (oid) and GuestTenantId (from idp claim)
- ✅ **WAF protection** - Azure Front Door Premium with managed rules
- ✅ **JWT validation** - API Management validates Entra ID tokens
- ✅ **End-to-end observability** - Application Insights with correlated telemetry

## Repository Structure

```
├── infra/                          # Bicep infrastructure as code
│   ├── main.bicep                  # Main orchestration template
│   ├── modules/                    # Reusable Bicep modules
│   └── parameters/                 # Environment-specific parameters
├── src/
│   ├── frontend/                   # React application
│   └── backend/                    # FastAPI application
├── apim/                           # API Management policies and definitions
│   ├── policies/                   # APIM policy files
│   └── api-definition.yaml         # OpenAPI specification
├── scripts/                        # Setup and automation scripts
│   └── setup-oidc-credentials.sh   # GitHub OIDC configuration
└── .github/workflows/              # CI/CD pipelines
```

## Implementation Tasks

### Infrastructure Setup
- [ ] T1 - Initialize repo & scaffolding ✅
- [ ] T2 - Bicep modules (infrastructure as code)
- [ ] T3 - Entra ID app registrations (SPA + Web API)
- [ ] T4 - GitHub OIDC federated credentials for CI/CD
- [ ] T5 - GitHub Actions: deploy infrastructure

### Application Development
- [ ] T6 - Build & deploy containers (frontend + backend)
- [ ] T7 - APIM: Validate JWT, enrich headers, enforce presence
- [ ] T8 - Backend (FastAPI) - MSI to Blob
- [ ] T9 - Frontend (React) - MSAL + calls via Front Door

### Security & Operations
- [ ] T10 - WAF & security hardening
- [ ] T11 - Observability (Application Insights)
- [ ] T12 - Private by default validation

## Prerequisites

- Azure subscription with permissions to create resources
- Microsoft Entra ID tenant with admin permissions
- GitHub repository with Actions enabled
- Local tools: `az`, `bicep`, `docker`, `node`, `python3`

## Getting Started

### 1. Set up GitHub OIDC for Azure

Run the setup script to configure Azure authentication:

```bash
./scripts/setup-oidc.sh fjgomariz fd-fb-apim rg-fd-fb-apim
```

### 2. Add GitHub Secrets and Variables

Add the three secrets output by the script to your GitHub repository:
- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`

Go to: `https://github.com/fjgomariz/fd-fb-apim/settings/secrets/actions`

Also add the following **repository variable** (not a secret):
- `AZURE_RESOURCE_GROUP` - The name of the resource group where infrastructure will be deployed (e.g., `rg-fd-fb-apim`)

Go to: `https://github.com/fjgomariz/fd-fb-apim/settings/variables/actions`

### 3. Deploy Infrastructure

Use the GitHub Actions workflows to deploy:
- `deploy-infra.yml` - Deploy Azure infrastructure
- `build-and-deploy-frontend.yml` - Build and deploy frontend
- `build-and-deploy-backend.yml` - Build and deploy backend

See [scripts/README.md](scripts/README.md) for more details.

## Cost Considerations

⚠️ **Note**: Azure Front Door Premium and API Management incur significant costs. For demos, consider using:
- API Management Developer tier
- Standard Front Door (with limitations)

## License

MIT
