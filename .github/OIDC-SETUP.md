# GitHub OIDC Setup for Azure Deployment

This guide explains how to set up secure, keyless authentication from GitHub Actions to Azure using OpenID Connect (OIDC) federated credentials.

## Overview

GitHub OIDC integration allows GitHub Actions workflows to authenticate to Azure without storing long-lived secrets. Instead, GitHub generates short-lived tokens that Azure validates using federated identity credentials.

## Benefits

- ✅ **No secrets in GitHub** - Uses temporary OIDC tokens instead of service principal passwords
- ✅ **Short-lived credentials** - Tokens expire after the workflow run completes
- ✅ **Scoped access** - Service principal has limited permissions (Contributor on resource group only)
- ✅ **Auditable** - All actions logged in Azure Activity Log with service principal identity
- ✅ **Revocable** - Can be disabled by removing the federated credential

## Architecture

```
┌─────────────────┐
│ GitHub Actions  │
│   Workflow      │
└────────┬────────┘
         │ 1. Request OIDC token
         │    (signed by GitHub)
         ▼
┌─────────────────┐
│ GitHub OIDC     │
│   Provider      │
└────────┬────────┘
         │ 2. Issue JWT token with claims:
         │    - iss: https://token.actions.githubusercontent.com
         │    - sub: repo:org/repo:environment:env
         │    - aud: api://AzureADTokenExchange
         ▼
┌─────────────────┐
│ Azure AD        │
│ (Entra ID)      │
└────────┬────────┘
         │ 3. Validate token signature
         │ 4. Match subject to federated credential
         │ 5. Issue Azure AD access token
         ▼
┌─────────────────┐
│ Azure Resources │
│ (via RBAC)      │
└─────────────────┘
```

## Prerequisites

Before running the setup script, ensure you have:

1. **Azure CLI** installed and authenticated
   ```bash
   az login
   az account show  # Verify you're in the correct subscription
   ```

2. **jq** installed (for JSON processing)
   ```bash
   # macOS
   brew install jq
   
   # Ubuntu/Debian
   sudo apt-get install jq
   
   # Windows (via chocolatey)
   choco install jq
   ```

3. **Azure AD permissions** - One of:
   - Application Administrator
   - Global Administrator
   - Cloud Application Administrator

4. **Azure RBAC permissions** - One of:
   - Owner on the subscription or resource group
   - User Access Administrator on the subscription or resource group

## Setup Steps

### Step 1: Run the Setup Script

The setup script automates the creation of the service principal and federated credential:

```bash
./scripts/setup-oidc-credentials.sh <github-org> <github-repo> <environment> <resource-group-name> [subscription-id]
```

**Example:**
```bash
./scripts/setup-oidc-credentials.sh fjgomariz fd-fb-apim dev rg-sample-privapp-weu
```

The script will:
1. ✅ Create a service principal named `sp-github-{repo}-{env}`
2. ✅ Grant Contributor role on the specified resource group
3. ✅ Add federated credential with subject `repo:{org}/{repo}:environment:{env}`
4. ✅ Output the required GitHub secrets

### Step 2: Configure GitHub Secrets

After the script completes, add the three secrets to your GitHub repository:

1. Go to your repository on GitHub
2. Navigate to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret** and add:

| Secret Name | Value | Description |
|-------------|-------|-------------|
| `AZURE_CLIENT_ID` | Output from script | Service principal application (client) ID |
| `AZURE_TENANT_ID` | Output from script | Azure AD tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Output from script | Azure subscription ID |

**Direct link**: `https://github.com/{org}/{repo}/settings/secrets/actions`

### Step 3: Create GitHub Environment

Create a GitHub environment that matches the environment name used in the setup script:

1. Go to **Settings** → **Environments**
2. Click **New environment**
3. Enter the environment name (e.g., `dev`)
4. Optionally configure:
   - **Required reviewers** - Require approval before deployment
   - **Wait timer** - Delay before deployment
   - **Deployment branches** - Restrict which branches can deploy

**Direct link**: `https://github.com/{org}/{repo}/settings/environments`

### Step 4: Verify Workflow Configuration

Ensure your workflows include the following configuration:

```yaml
jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: dev  # Must match the environment from Step 1
    permissions:
      id-token: write  # Required for OIDC token
      contents: read   # Required to checkout code
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Azure Login with OIDC
        uses: azure/login@v2
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
      
      - name: Run Azure CLI commands
        run: |
          az account show
          az group list
```

## Multiple Environments

To support multiple environments (dev, staging, prod), run the setup script for each environment:

```bash
# Development environment
./scripts/setup-oidc-credentials.sh fjgomariz fd-fb-apim dev rg-sample-privapp-dev

# Staging environment
./scripts/setup-oidc-credentials.sh fjgomariz fd-fb-apim staging rg-sample-privapp-staging

# Production environment
./scripts/setup-oidc-credentials.sh fjgomariz fd-fb-apim prod rg-sample-privapp-prod
```

Each environment creates:
- Separate service principal (`sp-github-fd-fb-apim-dev`, `sp-github-fd-fb-apim-staging`, etc.)
- Separate federated credential
- Scoped permissions to that environment's resource group

The **same GitHub secrets** can be used across environments because the `environment:` context in the workflow determines which service principal is used.

## Security Considerations

### Federated Credential Subject

The federated credential subject format is:
```
repo:{org}/{repo}:environment:{env}
```

This means the credential can **only** be used:
- ✅ From the specified GitHub repository
- ✅ Within the specified GitHub environment
- ❌ Not from forks
- ❌ Not from other repositories
- ❌ Not from other environments

### Least Privilege

The service principal is granted **Contributor** role only on the specified resource group, not the entire subscription. This follows the principle of least privilege.

To grant more granular permissions, modify the script or manually adjust role assignments:

```bash
# Example: Grant only specific permissions
az role assignment create \
  --assignee <app-id> \
  --role "Website Contributor" \
  --scope "/subscriptions/<sub-id>/resourceGroups/<rg-name>/providers/Microsoft.Web/sites/<webapp-name>"
```

### Token Lifetime

OIDC tokens issued by GitHub are short-lived (typically 10-15 minutes) and automatically expire after the workflow run completes.

## Troubleshooting

### Error: "Login failed with Error: Using auth-type: OIDC. Not all values are present."

**Cause**: Missing or incorrect GitHub secrets.

**Solution**: Verify all three secrets are set correctly:
- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`

### Error: "AADSTS70021: No matching federated identity record found"

**Cause**: Workflow is not using the correct environment, or environment name doesn't match.

**Solution**: 
1. Verify the workflow has `environment: dev` (or correct environment name)
2. Verify the GitHub environment exists in repository settings
3. Verify the federated credential subject matches: `repo:{org}/{repo}:environment:{env}`

```bash
# Check federated credentials
az ad app federated-credential list --id <app-id> --query "[].{Name:name, Subject:subject}"
```

### Error: "Insufficient privileges to complete the operation"

**Cause**: Service principal doesn't have required permissions on the resource group.

**Solution**: Verify role assignment exists:
```bash
az role assignment list --assignee <app-id> --all
```

If missing, re-run the setup script or manually add:
```bash
az role assignment create \
  --assignee <app-id> \
  --role "Contributor" \
  --scope "/subscriptions/<sub-id>/resourceGroups/<rg-name>"
```

### Error: "The subscription is not registered to use namespace 'Microsoft.Web'"

**Cause**: Required resource providers not registered in subscription.

**Solution**: Register required providers:
```bash
az provider register --namespace Microsoft.Web
az provider register --namespace Microsoft.ContainerRegistry
az provider register --namespace Microsoft.Storage
az provider register --namespace Microsoft.Network
az provider register --namespace Microsoft.ApiManagement
```

## Validation

After setup, validate the OIDC configuration:

### Test 1: Trigger a Workflow

```bash
# Trigger workflow manually
gh workflow run deploy-infra.yml
```

### Test 2: Check Azure Login

The workflow should log in successfully and display account information:
```
Run azure/login@v2
Login successful.
```

### Test 3: Verify Permissions

The workflow should be able to query the resource group:
```bash
az group show --name rg-sample-privapp-weu
```

## Cleanup

To remove the service principal and federated credentials:

```bash
# List service principals
az ad sp list --display-name "sp-github-fd-fb-apim-dev" --query "[].{Name:displayName, AppId:appId}" -o table

# Delete service principal (also removes federated credentials)
az ad sp delete --id <app-id>

# Remove role assignments (optional, automatically removed with SP)
az role assignment delete --assignee <app-id>
```

## References

- [Azure Workload Identity Federation](https://learn.microsoft.com/azure/active-directory/develop/workload-identity-federation)
- [GitHub OIDC with Azure](https://docs.github.com/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-azure)
- [Azure Login Action](https://github.com/Azure/login)
- [GitHub Environments](https://docs.github.com/actions/deployment/targeting-different-environments/using-environments-for-deployment)

## Next Steps

After completing OIDC setup:

1. ✅ **Deploy Infrastructure**: Run the `deploy-infra.yml` workflow
2. ✅ **Build Containers**: Run the `build-and-deploy-frontend.yml` and `build-and-deploy-backend.yml` workflows
3. ✅ **Configure Entra ID**: Set up app registrations for authentication (Task 3)
4. ✅ **Configure APIM**: Deploy JWT validation policies (Task 7)
