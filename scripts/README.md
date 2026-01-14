# Setup Script

## setup-oidc.sh

Sets up GitHub OIDC authentication for Azure deployments.

### Prerequisites

- Azure CLI installed and logged in (`az login`)
- Permissions to create service principals and assign roles

### Usage

```bash
./scripts/setup-oidc.sh <github-org> <github-repo> <resource-group-name>
```

### Example

```bash
./scripts/setup-oidc.sh fjgomariz fd-fb-apim rg-sample-privapp-weu
```

### What it does

1. Creates an Azure service principal named `sp-github-{repo}`
2. Grants Contributor role on the specified resource group
3. Adds a federated credential for GitHub Actions authentication
4. Outputs the secrets you need to add to GitHub

### After running

Add the three output values as GitHub repository secrets:
- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`

Go to: `https://github.com/{org}/{repo}/settings/secrets/actions`

That's it! Your workflows will automatically authenticate to Azure.
