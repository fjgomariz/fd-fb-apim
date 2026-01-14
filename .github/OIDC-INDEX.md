# Task 4: GitHub OIDC Federated Credentials - Documentation Index

This directory contains all documentation for Task 4: GitHub OIDC federated credentials for CI/CD.

## 📋 Quick Navigation

### For First-Time Setup
Start here if you're setting up OIDC for the first time:

1. **[QUICKSTART-OIDC.md](../QUICKSTART-OIDC.md)** ⭐ START HERE
   - 3-step quick setup guide
   - Minimal instructions to get started
   - Perfect for experienced users

2. **[OIDC-CHECKLIST.md](OIDC-CHECKLIST.md)** 
   - Step-by-step verification checklist
   - Prerequisites verification
   - Test procedures
   - Troubleshooting common issues

### For Detailed Understanding
Read these to understand how everything works:

3. **[OIDC-SETUP.md](OIDC-SETUP.md)**
   - Complete setup guide
   - Architecture overview
   - Security considerations
   - Multi-environment setup
   - Validation and testing

4. **[OIDC-FLOW.md](OIDC-FLOW.md)**
   - Visual authentication flow diagrams
   - Runtime authentication process
   - Security benefits explanation
   - Subject format details

### For Script Reference
Reference documentation for the automation script:

5. **[../scripts/README.md](../scripts/README.md)**
   - Setup script documentation
   - Prerequisites and installation
   - Usage examples and arguments
   - Troubleshooting guide
   - Cleanup procedures

## 🎯 Task 4 Requirements

From the issue: *"Write an `az ad sp create-for-rbac` (or Graph-based) flow that creates a deployment service principal, grants Contributor on the resource group, and adds a federated credential for this repo with subject `repo:<org>/<repo>:environment:<env>`. Produce a snippet for `azure/login@v2` configuring client-id, tenant-id, subscription-id."*

### ✅ Implementation Status

- [x] **Setup Script Created**: `scripts/setup-oidc-credentials.sh`
  - Creates service principal with `az ad sp create-for-rbac`
  - Grants Contributor role on resource group
  - Adds federated credential with correct subject format
  - Outputs configuration for GitHub secrets

- [x] **Workflow Snippets Provided**: All three workflows updated
  - `deploy-infra.yml`
  - `build-and-deploy-frontend.yml`
  - `build-and-deploy-backend.yml`
  
  Each with complete `azure/login@v2` configuration:
  ```yaml
  - uses: azure/login@v2
    with:
      client-id: ${{ secrets.AZURE_CLIENT_ID }}
      tenant-id: ${{ secrets.AZURE_TENANT_ID }}
      subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
  ```

- [x] **Complete Documentation Suite**
  - Quick start guide
  - Detailed setup guide
  - Visual flow diagrams
  - Verification checklist
  - Script documentation

## 📂 File Structure

```
.
├── .github/
│   ├── OIDC-SETUP.md          # Detailed setup guide (327 lines)
│   ├── OIDC-FLOW.md           # Flow diagrams (221 lines)
│   ├── OIDC-CHECKLIST.md      # Verification checklist (267 lines)
│   ├── OIDC-INDEX.md          # This file
│   └── workflows/
│       ├── deploy-infra.yml               # ✅ Updated with OIDC
│       ├── build-and-deploy-frontend.yml  # ✅ Updated with OIDC
│       └── build-and-deploy-backend.yml   # ✅ Updated with OIDC
├── scripts/
│   ├── setup-oidc-credentials.sh  # Main setup script (267 lines)
│   └── README.md                  # Script documentation (195 lines)
├── QUICKSTART-OIDC.md             # Quick start (81 lines)
└── README.md                      # ✅ Updated with OIDC section
```

## 🔑 Key Concepts

### Federated Credential Subject Format
```
repo:fjgomariz/fd-fb-apim:environment:dev
│    │         │           │            │
│    │         │           │            └─ Environment name
│    │         │           └────────────── Literal "environment:"
│    │         └────────────────────────── Repository name
│    └──────────────────────────────────── Organization/owner
└───────────────────────────────────────── Literal "repo:"
```

### GitHub Secrets Required
After running the setup script, add these to your repository:
- `AZURE_CLIENT_ID` - Service principal application (client) ID
- `AZURE_TENANT_ID` - Azure AD tenant ID
- `AZURE_SUBSCRIPTION_ID` - Azure subscription ID

### GitHub Environment Required
Create an environment in GitHub that matches the name used in the setup script:
- Default: `dev`
- Optional: `staging`, `prod`

## 🔒 Security Features

✅ **No Long-Lived Secrets**
- OIDC tokens expire after 10-15 minutes
- No passwords stored in GitHub

✅ **Scoped Access**
- Repository-specific (only `fjgomariz/fd-fb-apim`)
- Environment-specific (e.g., only `dev`)
- Resource-scoped (only specified resource group)

✅ **Auditable**
- All actions logged in Azure Activity Log
- Service principal identity tracked

✅ **Revocable**
- Delete federated credential to disable access
- No need to rotate secrets

## 🚀 Quick Start Command

```bash
# Run this command to set up OIDC for the dev environment
./scripts/setup-oidc-credentials.sh fjgomariz fd-fb-apim dev rg-sample-privapp-weu
```

Then follow the output instructions to:
1. Add the three GitHub secrets
2. Create the GitHub environment
3. Run a workflow to test

## 📖 Documentation Reading Order

For maximum efficiency, read in this order:

1. **[QUICKSTART-OIDC.md](../QUICKSTART-OIDC.md)** - Get started immediately (5 min read)
2. **[OIDC-CHECKLIST.md](OIDC-CHECKLIST.md)** - Follow step-by-step (15 min)
3. **[OIDC-SETUP.md](OIDC-SETUP.md)** - Understand the details (20 min read)
4. **[OIDC-FLOW.md](OIDC-FLOW.md)** - See how it works (10 min read)
5. **[scripts/README.md](../scripts/README.md)** - Script reference (as needed)

## 🆘 Getting Help

### Quick Troubleshooting
- **Login fails**: Check [OIDC-CHECKLIST.md](OIDC-CHECKLIST.md) - Troubleshooting section
- **Environment issues**: See [OIDC-SETUP.md](OIDC-SETUP.md) - Common Error Messages
- **Script errors**: Check [scripts/README.md](../scripts/README.md) - Troubleshooting

### Common Issues
1. **"No matching federated identity"** → Environment name mismatch
2. **"Application not found"** → Incorrect AZURE_CLIENT_ID secret
3. **"Insufficient privileges"** → Missing role assignment

See [OIDC-CHECKLIST.md](OIDC-CHECKLIST.md#common-error-messages-) for complete error reference.

## ✅ Verification

After setup, verify everything works:
```bash
# 1. Check service principal exists
az ad sp list --display-name "sp-github-fd-fb-apim-dev"

# 2. Check federated credential
az ad app federated-credential list --id <app-id>

# 3. Check role assignment
az role assignment list --assignee <app-id>

# 4. Test workflow
gh workflow run deploy-infra.yml
```

## 📊 Implementation Statistics

- **Files Created**: 6
- **Files Updated**: 4
- **Total Lines Added**: 1,706
- **Documentation Pages**: 6
- **Code Lines (script)**: 267
- **Workflow Updates**: 3

## 🎓 Learning Resources

- [Azure Workload Identity Federation](https://learn.microsoft.com/azure/active-directory/develop/workload-identity-federation)
- [GitHub OIDC with Azure](https://docs.github.com/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-azure)
- [Azure Login Action](https://github.com/Azure/login)
- [GitHub Environments](https://docs.github.com/actions/deployment/targeting-different-environments/using-environments-for-deployment)

---

**Task Status**: ✅ Complete  
**Last Updated**: 2024-01-14  
**Version**: 1.0
