# Deployment Configuration Guide

This document explains how to configure GitHub Actions for deploying the fd-fb-apim infrastructure and applications.

## Required GitHub Secrets

The following secrets must be configured in your GitHub repository settings at:
`https://github.com/fjgomariz/fd-fb-apim/settings/secrets/actions`

### Authentication Secrets
- **`AZURE_CLIENT_ID`** - The client ID of the Azure service principal (obtained from OIDC setup script)
- **`AZURE_TENANT_ID`** - Your Azure tenant ID
- **`AZURE_SUBSCRIPTION_ID`** - Your Azure subscription ID

These secrets are used for OIDC authentication with Azure (no passwords or keys stored).

## Required GitHub Variables

The following repository variable must be configured at:
`https://github.com/fjgomariz/fd-fb-apim/settings/variables/actions`

### Deployment Configuration
- **`AZURE_RESOURCE_GROUP`** - The name of the Azure resource group where all infrastructure will be deployed
  - Example: `rg-fd-fb-apim`
  - This variable is used by all three workflows:
    - `deploy-infra.yml` - Creates/uses this resource group for infrastructure deployment
    - `build-and-deploy-frontend.yml` - Deploys frontend container to web app in this resource group
    - `build-and-deploy-backend.yml` - Deploys backend container to web app in this resource group

## Resource Naming Convention

All Azure resources follow the naming pattern **`fd-fb-apim`** or **`fdfbapim`** (when special characters are not allowed):

| Resource Type | Name |
|---------------|------|
| Container Registry | `fdfbapim` |
| Frontend Web App | `fd-fb-apim-frontend` |
| Backend Web App | `fd-fb-apim-backend` |
| Storage Account | `fdfbapim` |
| API Management | `fd-fb-apim` |
| Front Door | `fd-fb-apim` |
| Application Insights | `fd-fb-apim` |
| Log Analytics Workspace | `fd-fb-apim` |
| Key Vault | `fd-fb-apim` |
| Virtual Network | `fd-fb-apim` |
| App Service Plan | `fd-fb-apim` |

These names are defined in `infra/parameters/main.parameters.json` and can be customized as needed.

## Deployment Workflows

### 1. Infrastructure Deployment (`deploy-infra.yml`)
Deploys all Azure infrastructure using Bicep templates.

**Triggers:**
- Manual: `workflow_dispatch`
- Automatic: On push to `infra/**` paths

**Steps:**
1. Logs in to Azure using OIDC
2. Installs and runs Bicep CLI to build templates
3. Creates resource group if it doesn't exist (uses `AZURE_RESOURCE_GROUP` variable)
4. Runs `what-if` analysis to preview changes
5. Deploys infrastructure using `infra/main.bicep` with parameters from `infra/parameters/main.parameters.json`
6. Outputs deployment results and uploads artifacts

### 2. Frontend Deployment (`build-and-deploy-frontend.yml`)
Builds and deploys the React frontend container.

**Triggers:**
- Manual: `workflow_dispatch`
- Automatic: On push to `src/frontend/**` paths

**Requirements:**
- Infrastructure must be deployed first
- Uses `AZURE_RESOURCE_GROUP` variable to locate resources

### 3. Backend Deployment (`build-and-deploy-backend.yml`)
Builds and deploys the FastAPI backend container.

**Triggers:**
- Manual: `workflow_dispatch`
- Automatic: On push to `src/backend/**` paths

**Requirements:**
- Infrastructure must be deployed first
- Uses `AZURE_RESOURCE_GROUP` variable to locate resources

## Setup Steps

1. **Run the OIDC setup script:**
   ```bash
   ./scripts/setup-oidc.sh fjgomariz fd-fb-apim rg-fd-fb-apim
   ```

2. **Add GitHub Secrets:**
   - Go to repository Settings → Secrets and variables → Actions → Secrets
   - Add `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`

3. **Add GitHub Variable:**
   - Go to repository Settings → Secrets and variables → Actions → Variables
   - Add `AZURE_RESOURCE_GROUP` with your resource group name (e.g., `rg-fd-fb-apim`)

4. **Deploy Infrastructure:**
   - Go to Actions → Deploy Infrastructure → Run workflow
   - Or push changes to `infra/**` to trigger automatically

5. **Deploy Applications:**
   - After infrastructure is deployed, run the frontend and backend workflows
   - Or push changes to `src/frontend/**` or `src/backend/**`

## Notes

- The resource group name is **no longer** stored in the Bicep parameters file
- It must be configured as a GitHub Actions variable (`AZURE_RESOURCE_GROUP`)
- This allows different environments to use different resource groups without modifying code
- All resource names follow the `fd-fb-apim` pattern for consistency
