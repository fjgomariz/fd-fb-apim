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

Before deploying infrastructure, configure GitHub Actions to authenticate to Azure using OIDC (no secrets required):

```bash
# Run the setup script
./scripts/setup-oidc-credentials.sh <github-org> <github-repo> <environment> <resource-group-name>

# Example:
./scripts/setup-oidc-credentials.sh fjgomariz fd-fb-apim dev rg-sample-privapp-weu
```

**📚 Documentation:**
- **Quick Start**: [QUICKSTART-OIDC.md](QUICKSTART-OIDC.md) - 3-step setup guide
- **Detailed Guide**: [.github/OIDC-SETUP.md](.github/OIDC-SETUP.md) - Complete setup instructions
- **Flow Diagram**: [.github/OIDC-FLOW.md](.github/OIDC-FLOW.md) - Visual authentication flow
- **Script Reference**: [scripts/README.md](scripts/README.md) - Script documentation

See [scripts/README.md](scripts/README.md) for detailed setup instructions.

### 2. Configure GitHub Secrets

Add the output values from the setup script as GitHub repository secrets:
- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`

### 3. Deploy Infrastructure

Once OIDC is configured, use GitHub Actions workflows to deploy infrastructure and applications.

See [.github/copilot-instructions.md](.github/copilot-instructions.md) for detailed implementation guidance and step-by-step prompts for each task.

## Cost Considerations

⚠️ **Note**: Azure Front Door Premium and API Management incur significant costs. For demos, consider using:
- API Management Developer tier
- Standard Front Door (with limitations)

## License

MIT
