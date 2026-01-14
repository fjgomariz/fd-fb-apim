# Infrastructure as Code - Bicep Modules

This directory contains all the Bicep infrastructure modules for deploying a private-by-default web application on Azure.

## Architecture Overview

The infrastructure deploys:
- **Frontend**: React Web App (Linux containers) with VNet integration
- **Backend**: FastAPI Web App (Linux containers) with VNet integration
- **API Gateway**: Azure API Management (Internal VNet mode) for JWT validation and identity propagation
- **CDN/WAF**: Azure Front Door Premium with WAF policy and Private Link origins
- **Storage**: Azure Blob Storage with private endpoint
- **Monitoring**: Application Insights and Log Analytics
- **Security**: Managed Identities, RBAC, Private Endpoints, Key Vault

## Module Structure

### Core Infrastructure Modules

#### `rg.bicep`
Creates the Azure Resource Group at subscription scope.

**Outputs:**
- Resource Group ID, name, and location

#### `vnet.bicep`
Virtual Network with configurable subnets for:
- APIM subnet (10.0.1.0/24)
- Web Apps subnet (10.0.2.0/27) - delegated to Microsoft.Web/serverFarms
- Private Endpoints subnet (10.0.3.0/24)

**Outputs:**
- VNet ID, subnet IDs, subnet details

#### `log-analytics.bicep`
Log Analytics Workspace for centralized logging.

**Parameters:**
- Retention period (30-730 days)
- SKU (PerGB2018, Free, Standalone, etc.)

**Outputs:**
- Workspace ID and customer ID

#### `app-insights.bicep`
Application Insights linked to Log Analytics.

**Outputs:**
- Instrumentation key, connection string

### Compute Resources

#### `acr.bicep`
Azure Container Registry (Premium SKU) for storing container images.

**Features:**
- Admin user disabled (uses MSI)
- Retention policy enabled (7 days)
- Network rule bypass for Azure services

**Outputs:**
- Login server, resource ID

#### `appservice-plan.bicep`
Linux App Service Plan for hosting containerized web apps.

**Default SKU:** P1V3 (Production-ready)

**Outputs:**
- Plan ID and name

#### `webapp.bicep`
Generic Web App for Containers module. Creates:
- Linux Web App with system-assigned managed identity
- Container image configuration with ACR integration
- Optional VNet integration
- Application settings

**Key Features:**
- ACR authentication via Managed Identity (`acrUseManagedIdentityCreds`)
- HTTPS only, HTTP/2 enabled
- TLS 1.2 minimum
- FTPS disabled

**Outputs:**
- App hostname, managed identity principal ID

### API & Security

#### `apim.bicep`
API Management service with:
- Developer or Premium SKU
- Internal VNet mode
- Application Insights integration
- System-assigned managed identity
- TLS 1.2+ enforcement

**Outputs:**
- Gateway URL, principal ID, private IP addresses

#### `keyvault.bicep`
Key Vault with:
- RBAC authorization
- Soft delete and purge protection
- Private network access
- Private endpoint support

**Outputs:**
- Vault URI, resource ID

### Storage

#### `storage.bicep`
Storage Account with:
- Blob service
- Container named "uploads"
- Soft delete enabled (7 days retention)
- Public access disabled
- TLS 1.2 minimum
- Private endpoint support

**Outputs:**
- Blob endpoint, container name

### Networking & Security

#### `private-endpoints.bicep`
Creates private endpoints and DNS zones for:
- Web Apps (frontend & backend)
- API Management
- Storage Blob
- Key Vault

**Features:**
- Automatic private DNS zone creation
- VNet links for DNS resolution
- Private DNS zone groups for endpoint configuration

**DNS Zones Created:**
- `privatelink.azurewebsites.net`
- `privatelink.azure-api.net`
- `privatelink.blob.core.windows.net`
- `privatelink.vaultcore.azure.net`

**Outputs:**
- Private endpoint IDs

#### `frontdoor.bicep`
Azure Front Door Premium with:
- WAF policy (managed rules + custom blocklist)
- Origin groups with Private Link connections
- Routes:
  - `/` → Frontend Web App
  - `/api/*` → API Management
- HTTPS-only, HTTPS redirect
- Managed rule sets:
  - Microsoft Default Rule Set 2.1
  - Bot Manager Rule Set 1.0

**Outputs:**
- Endpoint hostname, WAF policy ID

### RBAC

#### `rbac-assignments.bicep`
Role assignments for managed identities:
- **Frontend & Backend → ACR**: `AcrPull` role for pulling container images
- **Backend → Storage**: `Storage Blob Data Contributor` role for blob operations

## Main Orchestration Template

### `main.bicep`
Subscription-scoped template that orchestrates all modules.

**Key Parameters:**
- `location`: Azure region (default: westeurope)
- `environment`: dev/test/prod
- `names`: Object containing all resource names
- `apimPublisherEmail` and `apimPublisherName`
- `apimSku`: Developer/Premium/StandardV2
- Container images for frontend and backend

**Deployment Flow:**
1. Resource Group
2. Virtual Network
3. Monitoring (Log Analytics, App Insights)
4. Container Registry
5. App Service Plan
6. Web Apps (Frontend & Backend)
7. Storage Account
8. API Management
9. Key Vault
10. Private Endpoints
11. Front Door
12. RBAC Assignments

**Outputs:**
- Resource group name
- Front Door endpoint URL
- Web app hostnames
- APIM gateway URL
- ACR login server
- App Insights connection string
- Storage account name
- Key Vault URI

## Parameters File

### `parameters/main.parameters.json`
Example parameter values including:
- Resource names (must be globally unique where applicable)
- APIM publisher details
- Container image references

**Note:** Update resource names to ensure global uniqueness, especially for:
- Storage account name (3-24 lowercase alphanumeric)
- ACR name (5-50 alphanumeric)
- Front Door profile name

## Deployment

### Prerequisites
```bash
az login
az account set --subscription <subscription-id>
```

### Validate
```bash
az deployment sub what-if \
  --location westeurope \
  --template-file infra/main.bicep \
  --parameters @infra/parameters/main.parameters.json
```

### Deploy
```bash
az deployment sub create \
  --name infra-deployment \
  --location westeurope \
  --template-file infra/main.bicep \
  --parameters @infra/parameters/main.parameters.json
```

### Build Locally
```bash
bicep build infra/main.bicep
```

## Security Highlights

✅ **No plaintext secrets** - All authentication uses Managed Identities  
✅ **Private endpoints** - Storage, APIM, Web Apps, Key Vault  
✅ **RBAC least privilege** - Scoped role assignments  
✅ **WAF protection** - Front Door Premium with managed rules  
✅ **TLS 1.2+** - Enforced across all services  
✅ **HTTPS only** - HTTP automatically redirected  
✅ **Network isolation** - Internal VNet for APIM, delegated subnet for Web Apps  

## Estimated Deployment Time

- **Initial deployment**: 45-60 minutes (APIM provisioning takes ~30-40 mins)
- **Front Door**: ~5-10 minutes
- **Private endpoints**: ~5 minutes
- **Other resources**: ~10-15 minutes

## Cost Considerations

⚠️ **High-cost resources:**
- **Azure Front Door Premium**: ~$330/month base + data transfer
- **API Management Premium**: ~$2,700/month (Developer: ~$50/month)
- **App Service P1V3**: ~$150/month

💡 **For development/testing:**
- Use APIM Developer tier
- Consider Standard Front Door (limited Private Link support)
- Use lower App Service SKU (B1, S1)

## Troubleshooting

### Common Issues

**1. Bicep build fails**
```bash
# Update Bicep CLI
az bicep upgrade
```

**2. Deployment timeout (APIM)**
- APIM deployment can take 30-40 minutes - this is normal
- Use `--no-wait` flag and check status separately

**3. Private endpoint connection pending**
- Manually approve private endpoint connections in Azure Portal
- Check Network settings of target resource

**4. Front Door health probe fails**
- Verify web apps are running
- Check that private endpoint connections are approved
- Ensure origin health probe path is accessible

**5. Name conflicts**
- Update resource names in parameters file
- Ensure global uniqueness for storage/ACR/Front Door

## Next Steps

After infrastructure deployment:
1. Build and push container images to ACR
2. Update Web App container settings with actual image tags
3. Configure APIM policies (see `/apim/policies/`)
4. Set up Entra ID app registrations
5. Configure APIM JWT validation policy
6. Deploy application code

See [/.github/copilot-instructions.md](../.github/copilot-instructions.md) for complete implementation guide.
