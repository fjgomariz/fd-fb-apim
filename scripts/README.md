# Scripts Directory

This directory contains automation scripts for setting up and managing the Azure infrastructure and GitHub integration.

## Setup Scripts

### `setup-oidc-credentials.sh`

Creates an Azure Service Principal with GitHub OIDC federated credentials for secure, keyless authentication from GitHub Actions to Azure.

**What it does:**
1. Creates an Azure Service Principal (or uses existing one)
2. Grants **Contributor** role on the specified resource group
3. Adds a federated credential for GitHub OIDC authentication
4. Outputs the required GitHub secrets configuration

**Prerequisites:**
- Azure CLI (`az`) installed and logged in (`az login`)
- `jq` command-line JSON processor installed
- Permissions to create service principals in Azure AD
- Permissions to assign roles on the target resource group

**Installation of Prerequisites:**

```bash
# Install Azure CLI
# macOS
brew install azure-cli

# Ubuntu/Debian
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Windows (PowerShell)
Invoke-WebRequest -Uri https://aka.ms/installazurecliwindows -OutFile .\AzureCLI.msi
Start-Process msiexec.exe -Wait -ArgumentList '/I AzureCLI.msi /quiet'

# Install jq
# macOS
brew install jq

# Ubuntu/Debian
sudo apt-get install jq

# Windows (via chocolatey)
choco install jq
```

**Usage:**

```bash
./scripts/setup-oidc-credentials.sh <github-org> <github-repo> <environment> <resource-group-name> [subscription-id]
```

**Arguments:**
- `github-org`: GitHub organization or username (e.g., `fjgomariz`)
- `github-repo`: GitHub repository name (e.g., `fd-fb-apim`)
- `environment`: GitHub environment name (e.g., `dev`, `staging`, `prod`)
- `resource-group-name`: Azure resource group name to grant Contributor access
- `subscription-id`: (Optional) Azure subscription ID. Uses current subscription if not provided

**Example:**

```bash
# Using default subscription
./scripts/setup-oidc-credentials.sh fjgomariz fd-fb-apim dev rg-sample-privapp-weu

# Specifying subscription ID explicitly
./scripts/setup-oidc-credentials.sh fjgomariz fd-fb-apim dev rg-sample-privapp-weu 12345678-1234-1234-1234-123456789012
```

**Output:**

The script will output three values that you need to add as GitHub repository secrets:

1. `AZURE_CLIENT_ID` - Application (client) ID of the service principal
2. `AZURE_TENANT_ID` - Azure AD tenant ID
3. `AZURE_SUBSCRIPTION_ID` - Azure subscription ID

**Post-Setup Steps:**

1. **Add GitHub Secrets:**
   - Navigate to: `https://github.com/<org>/<repo>/settings/secrets/actions`
   - Add the three secrets output by the script:
     - `AZURE_CLIENT_ID`
     - `AZURE_TENANT_ID`
     - `AZURE_SUBSCRIPTION_ID`

2. **Create GitHub Environment:**
   - Navigate to: `https://github.com/<org>/<repo>/settings/environments`
   - Create a new environment with the name you specified (e.g., `dev`)
   - Optionally configure environment protection rules

3. **Update GitHub Actions Workflows:**
   
   Your workflows should use the OIDC login pattern:

   ```yaml
   jobs:
     deploy:
       runs-on: ubuntu-latest
       environment: dev  # Must match the environment name from setup
       permissions:
         id-token: write  # Required for OIDC
         contents: read
       
       steps:
         - uses: actions/checkout@v4
         
         - name: Azure Login with OIDC
           uses: azure/login@v2
           with:
             client-id: ${{ secrets.AZURE_CLIENT_ID }}
             tenant-id: ${{ secrets.AZURE_TENANT_ID }}
             subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
         
         - name: Deploy resources
           run: |
             az group show --name rg-sample-privapp-weu
   ```

**Security Benefits:**

- ✅ **No secrets stored in GitHub** - Uses OpenID Connect (OIDC) tokens
- ✅ **Short-lived credentials** - Tokens are valid only for the workflow run
- ✅ **Scoped permissions** - Service principal only has access to specified resource group
- ✅ **Auditable** - All actions are logged in Azure Activity Log

**Troubleshooting:**

**Error: "az: command not found"**
- Install Azure CLI (see prerequisites above)

**Error: "jq: command not found"**
- Install jq (see prerequisites above)

**Error: "Not logged in to Azure CLI"**
- Run `az login` and authenticate
- Verify with `az account show`

**Error: "Insufficient privileges to create service principal"**
- You need the "Application Administrator" or "Global Administrator" role in Azure AD
- Contact your Azure AD administrator

**Error: "Insufficient privileges to assign roles"**
- You need "Owner" or "User Access Administrator" role on the subscription or resource group
- Contact your Azure subscription administrator

**Federated credential subject format:**

The script creates a federated credential with subject:
```
repo:<org>/<repo>:environment:<env>
```

This restricts the credential to only be usable:
- From the specified GitHub repository
- Within the specified GitHub environment

**Multiple Environments:**

To set up multiple environments (dev, staging, prod), run the script multiple times:

```bash
# Development environment
./scripts/setup-oidc-credentials.sh fjgomariz fd-fb-apim dev rg-sample-privapp-dev

# Staging environment
./scripts/setup-oidc-credentials.sh fjgomariz fd-fb-apim staging rg-sample-privapp-staging

# Production environment
./scripts/setup-oidc-credentials.sh fjgomariz fd-fb-apim prod rg-sample-privapp-prod
```

Each environment will create a separate service principal with scoped permissions.

**Cleanup:**

To remove the service principal and federated credentials:

```bash
# List service principals
az ad sp list --display-name "sp-github-fd-fb-apim-dev" --query "[].{Name:displayName, AppId:appId}" -o table

# Delete service principal (this also removes federated credentials)
az ad sp delete --id <app-id>

# Remove role assignment (if needed separately)
az role assignment delete --assignee <app-id> --scope "/subscriptions/<subscription-id>/resourceGroups/<resource-group>"
```

## References

- [Azure AD Workload Identity Federation](https://docs.microsoft.com/azure/active-directory/develop/workload-identity-federation)
- [GitHub Actions OIDC](https://docs.github.com/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)
- [Azure Login Action](https://github.com/Azure/login)
