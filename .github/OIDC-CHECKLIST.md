# GitHub OIDC Setup Checklist

Use this checklist to verify your GitHub OIDC setup is complete and working.

## Prerequisites ✓

- [ ] Azure CLI (`az`) installed and working
  ```bash
  az version
  ```

- [ ] jq installed (JSON processor)
  ```bash
  jq --version
  ```

- [ ] Logged in to Azure CLI
  ```bash
  az login
  az account show
  ```

- [ ] Correct Azure subscription selected
  ```bash
  az account set --subscription <subscription-id>
  ```

- [ ] Azure AD permissions (one of):
  - [ ] Application Administrator role
  - [ ] Global Administrator role
  - [ ] Cloud Application Administrator role

- [ ] Azure RBAC permissions (one of):
  - [ ] Owner on the subscription
  - [ ] Owner on the resource group
  - [ ] User Access Administrator on the subscription/resource group

## Setup Script Execution ✓

- [ ] Run setup script for dev environment
  ```bash
  ./scripts/setup-oidc-credentials.sh fjgomariz fd-fb-apim dev rg-sample-privapp-weu
  ```

- [ ] Script completed without errors

- [ ] Copy the three output values:
  - [ ] AZURE_CLIENT_ID: `________________________________`
  - [ ] AZURE_TENANT_ID: `________________________________`
  - [ ] AZURE_SUBSCRIPTION_ID: `________________________________`

- [ ] (Optional) Run for additional environments:
  - [ ] Staging: `./scripts/setup-oidc-credentials.sh ... staging ...`
  - [ ] Production: `./scripts/setup-oidc-credentials.sh ... prod ...`

## Azure Verification ✓

- [ ] Service principal created
  ```bash
  az ad sp list --display-name "sp-github-fd-fb-apim-dev" --query "[].{Name:displayName, AppId:appId}" -o table
  ```

- [ ] Federated credential created
  ```bash
  APP_ID="<your-app-id>"
  az ad app federated-credential list --id $APP_ID --query "[].{Name:name, Subject:subject}" -o table
  ```
  
  Expected subject: `repo:fjgomariz/fd-fb-apim:environment:dev`

- [ ] Role assignment exists
  ```bash
  APP_ID="<your-app-id>"
  az role assignment list --assignee $APP_ID --all -o table
  ```
  
  Expected: Contributor role on resource group

- [ ] Resource group exists (or will be created by deployment)
  ```bash
  az group show --name rg-sample-privapp-weu
  ```

## GitHub Configuration ✓

### Repository Secrets

- [ ] Navigate to: `https://github.com/fjgomariz/fd-fb-apim/settings/secrets/actions`

- [ ] Add secret: `AZURE_CLIENT_ID`
  - [ ] Value matches output from setup script
  - [ ] Secret visible in list (name only, value hidden)

- [ ] Add secret: `AZURE_TENANT_ID`
  - [ ] Value matches output from setup script
  - [ ] Secret visible in list (name only, value hidden)

- [ ] Add secret: `AZURE_SUBSCRIPTION_ID`
  - [ ] Value matches output from setup script
  - [ ] Secret visible in list (name only, value hidden)

### GitHub Environment

- [ ] Navigate to: `https://github.com/fjgomariz/fd-fb-apim/settings/environments`

- [ ] Create environment: `dev`
  - [ ] Environment name exactly matches setup script (case-sensitive)
  - [ ] Environment appears in list

- [ ] (Optional) Configure environment protection rules:
  - [ ] Required reviewers
  - [ ] Wait timer
  - [ ] Deployment branches

- [ ] (Optional) Create additional environments:
  - [ ] `staging`
  - [ ] `prod`

## Workflow Files Verification ✓

- [ ] Check `.github/workflows/deploy-infra.yml`:
  - [ ] Has `permissions: id-token: write`
  - [ ] Has `environment: ${{ github.event.inputs.environment || 'dev' }}`
  - [ ] Uses `azure/login@v2` with OIDC configuration

- [ ] Check `.github/workflows/build-and-deploy-frontend.yml`:
  - [ ] Has `permissions: id-token: write`
  - [ ] Has `environment: ${{ github.event.inputs.environment || 'dev' }}`
  - [ ] Uses `azure/login@v2` with OIDC configuration

- [ ] Check `.github/workflows/build-and-deploy-backend.yml`:
  - [ ] Has `permissions: id-token: write`
  - [ ] Has `environment: ${{ github.event.inputs.environment || 'dev' }}`
  - [ ] Uses `azure/login@v2` with OIDC configuration

## Test the Setup ✓

### Test 1: Manual Workflow Trigger

- [ ] Go to: `https://github.com/fjgomariz/fd-fb-apim/actions`

- [ ] Select workflow: "Deploy Infrastructure"

- [ ] Click "Run workflow"
  - [ ] Select branch: `main` (or current branch)
  - [ ] Select environment: `dev`
  - [ ] Click "Run workflow" button

- [ ] Wait for workflow to start

- [ ] Check "Azure Login with OIDC" step:
  - [ ] Step completes successfully (green checkmark)
  - [ ] No authentication errors
  - [ ] Output shows: "Login successful"

- [ ] Check subsequent Azure steps:
  - [ ] Can run `az account show`
  - [ ] Can access resource group
  - [ ] Can deploy resources (if infrastructure exists)

### Test 2: Verify Token Claims

- [ ] In workflow run, add a debug step:
  ```yaml
  - name: Debug Azure Context
    run: |
      az account show
      az ad signed-in-user show 2>&1 || echo "Using service principal (expected)"
  ```

- [ ] Verify service principal is being used (not user account)

### Test 3: Test Permissions

- [ ] Verify can deploy to resource group:
  ```yaml
  - run: az deployment group create --resource-group rg-sample-privapp-weu --template-file test.bicep
  ```

- [ ] Verify CANNOT access other resource groups (should fail):
  ```yaml
  - run: az group list --query "[?name!='rg-sample-privapp-weu']"
  ```

## Troubleshooting Checklist ✓

If authentication fails:

- [ ] Check environment name matches exactly:
  - [ ] In workflow: `environment: dev`
  - [ ] In GitHub: Environment named `dev` exists
  - [ ] In Azure: Federated credential subject ends with `:environment:dev`

- [ ] Check secrets are set correctly:
  - [ ] All three secrets exist in repository
  - [ ] No extra spaces or newlines in secret values
  - [ ] Copy/paste directly from script output

- [ ] Check workflow permissions:
  - [ ] `id-token: write` permission is set
  - [ ] Not blocked by organization-level settings

- [ ] Check service principal:
  - [ ] Service principal not disabled/deleted
  - [ ] Federated credential still exists
  - [ ] Role assignment still exists

- [ ] Check Azure AD:
  - [ ] Using correct tenant ID
  - [ ] No conditional access policies blocking service principals
  - [ ] Service principal not blocked by network restrictions

## Common Error Messages ✓

| Error | Likely Cause | Solution |
|-------|--------------|----------|
| `AADSTS70021: No matching federated identity record found` | Environment mismatch | Verify environment name matches in workflow and federated credential subject |
| `AADSTS700016: Application not found` | Incorrect client ID | Verify `AZURE_CLIENT_ID` secret matches service principal app ID |
| `AADSTS90002: Tenant not found` | Incorrect tenant ID | Verify `AZURE_TENANT_ID` secret matches Azure AD tenant ID |
| `Insufficient privileges to complete the operation` | Missing role assignment | Verify Contributor role assigned to service principal on resource group |
| `Using auth-type: OIDC. Not all values are present` | Missing secrets | Verify all three secrets (CLIENT_ID, TENANT_ID, SUBSCRIPTION_ID) are set |

## Success Criteria ✓

Your setup is complete when:

- [x] ✅ Setup script runs without errors
- [x] ✅ Service principal created in Azure AD
- [x] ✅ Federated credential created with correct subject
- [x] ✅ Role assignment grants Contributor on resource group
- [x] ✅ GitHub secrets configured (3 secrets)
- [x] ✅ GitHub environment created (matches subject)
- [x] ✅ Workflow runs successfully
- [x] ✅ Azure login step completes without errors
- [x] ✅ Can deploy resources to Azure

## Next Steps

After completing this checklist:

1. ✅ **Deploy Infrastructure**
   - Run workflow: `deploy-infra.yml`
   - Verify Bicep deployment succeeds

2. ✅ **Build and Deploy Applications**
   - Run workflow: `build-and-deploy-frontend.yml`
   - Run workflow: `build-and-deploy-backend.yml`

3. ✅ **Configure Entra ID App Registrations** (Task 3)
   - Create SPA app registration for frontend
   - Create API app registration for backend

4. ✅ **Configure APIM Policies** (Task 7)
   - Deploy JWT validation policy
   - Configure identity propagation

## Documentation References

- [QUICKSTART-OIDC.md](../QUICKSTART-OIDC.md) - Quick 3-step setup
- [.github/OIDC-SETUP.md](OIDC-SETUP.md) - Detailed setup guide
- [.github/OIDC-FLOW.md](OIDC-FLOW.md) - Authentication flow diagrams
- [scripts/README.md](../scripts/README.md) - Setup script documentation

---

**Last Updated**: 2024-01-14
**Version**: 1.0
