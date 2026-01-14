# Quick Start: GitHub OIDC Setup

## TL;DR - 3 Steps to Enable OIDC Authentication

### 1. Run the Setup Script

```bash
./scripts/setup-oidc-credentials.sh fjgomariz fd-fb-apim dev rg-sample-privapp-weu
```

### 2. Add GitHub Secrets

Go to: `https://github.com/fjgomariz/fd-fb-apim/settings/secrets/actions`

Add these three secrets (values from script output):
- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`

### 3. Create GitHub Environment

Go to: `https://github.com/fjgomariz/fd-fb-apim/settings/environments`

Create environment named: `dev`

## That's it! 🎉

Your GitHub Actions workflows can now authenticate to Azure without storing secrets.

---

## What the Script Does

1. ✅ Creates Azure service principal: `sp-github-fd-fb-apim-dev`
2. ✅ Grants **Contributor** role on resource group: `rg-sample-privapp-weu`
3. ✅ Adds federated credential: `repo:fjgomariz/fd-fb-apim:environment:dev`
4. ✅ Outputs configuration values for GitHub

## Example Workflow Usage

```yaml
jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: dev  # Matches setup script environment
    permissions:
      id-token: write  # Required for OIDC
      contents: read
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Azure Login
        uses: azure/login@v2
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
      
      - run: az account show
```

## Multiple Environments

For staging and prod:

```bash
# Staging
./scripts/setup-oidc-credentials.sh fjgomariz fd-fb-apim staging rg-sample-privapp-staging

# Production
./scripts/setup-oidc-credentials.sh fjgomariz fd-fb-apim prod rg-sample-privapp-prod
```

Then create `staging` and `prod` environments in GitHub.

## Need Help?

See full documentation:
- [scripts/README.md](scripts/README.md) - Script documentation
- [.github/OIDC-SETUP.md](.github/OIDC-SETUP.md) - Complete setup guide
