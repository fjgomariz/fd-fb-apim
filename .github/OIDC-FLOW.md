# GitHub OIDC Authentication Flow

## Setup Process

```
┌─────────────────────────────────────────────────────────────────────┐
│                    1. RUN SETUP SCRIPT                               │
│  ./scripts/setup-oidc-credentials.sh fjgomariz fd-fb-apim dev ...   │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    2. AZURE RESOURCES CREATED                        │
│                                                                       │
│  ┌───────────────────────────────────────────────────────────┐      │
│  │ Service Principal: sp-github-fd-fb-apim-dev               │      │
│  │ - Application ID: <guid>                                  │      │
│  │ - Tenant ID: <guid>                                       │      │
│  └───────────────────────────────────────────────────────────┘      │
│                             │                                        │
│                             ▼                                        │
│  ┌───────────────────────────────────────────────────────────┐      │
│  │ Federated Credential                                      │      │
│  │ - Name: github-fd-fb-apim-dev                            │      │
│  │ - Issuer: https://token.actions.githubusercontent.com     │      │
│  │ - Subject: repo:fjgomariz/fd-fb-apim:environment:dev     │      │
│  │ - Audience: api://AzureADTokenExchange                   │      │
│  └───────────────────────────────────────────────────────────┘      │
│                             │                                        │
│                             ▼                                        │
│  ┌───────────────────────────────────────────────────────────┐      │
│  │ RBAC Assignment                                           │      │
│  │ - Role: Contributor                                       │      │
│  │ - Scope: /subscriptions/{sub}/resourceGroups/{rg}        │      │
│  └───────────────────────────────────────────────────────────┘      │
└─────────────────────────────────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    3. CONFIGURE GITHUB                               │
│                                                                       │
│  ┌───────────────────────────────────────────────────────────┐      │
│  │ Repository Secrets (Settings → Secrets → Actions)         │      │
│  │ - AZURE_CLIENT_ID: <app-id>                              │      │
│  │ - AZURE_TENANT_ID: <tenant-id>                           │      │
│  │ - AZURE_SUBSCRIPTION_ID: <subscription-id>               │      │
│  └───────────────────────────────────────────────────────────┘      │
│                             │                                        │
│                             ▼                                        │
│  ┌───────────────────────────────────────────────────────────┐      │
│  │ Environment (Settings → Environments)                     │      │
│  │ - Name: dev                                               │      │
│  │ - Protection rules (optional)                             │      │
│  └───────────────────────────────────────────────────────────┘      │
└─────────────────────────────────────────────────────────────────────┘
```

## Runtime Authentication Flow

```
┌─────────────────────┐
│ GitHub Actions      │
│ Workflow Triggered  │
└──────────┬──────────┘
           │
           │ 1. Workflow starts with environment: dev
           ▼
┌─────────────────────────────────────────────────────────────────┐
│ Job Configuration                                               │
│                                                                 │
│   permissions:                                                  │
│     id-token: write  ◄── Allows requesting OIDC token          │
│     contents: read                                              │
│                                                                 │
│   environment: dev   ◄── Specifies environment (matches subject)│
└──────────┬──────────────────────────────────────────────────────┘
           │
           │ 2. Request OIDC token
           ▼
┌─────────────────────────────────────────────────────────────────┐
│ GitHub OIDC Provider                                            │
│ https://token.actions.githubusercontent.com                     │
│                                                                 │
│ Issues JWT with claims:                                         │
│   {                                                             │
│     "iss": "https://token.actions.githubusercontent.com",       │
│     "sub": "repo:fjgomariz/fd-fb-apim:environment:dev",        │
│     "aud": "api://AzureADTokenExchange",                       │
│     "repository": "fjgomariz/fd-fb-apim",                      │
│     "environment": "dev",                                       │
│     "exp": <short-lived-timestamp>                             │
│   }                                                             │
└──────────┬──────────────────────────────────────────────────────┘
           │
           │ 3. azure/login@v2 exchanges token
           ▼
┌─────────────────────────────────────────────────────────────────┐
│ Azure AD (Entra ID)                                             │
│ Token Validation:                                               │
│                                                                 │
│ ✅ Verify token signature (from GitHub)                        │
│ ✅ Check issuer matches:                                       │
│    https://token.actions.githubusercontent.com                  │
│ ✅ Check subject matches federated credential:                 │
│    repo:fjgomariz/fd-fb-apim:environment:dev                   │
│ ✅ Check audience matches:                                     │
│    api://AzureADTokenExchange                                   │
│                                                                 │
│ Issues Azure AD access token for service principal             │
└──────────┬──────────────────────────────────────────────────────┘
           │
           │ 4. Access Azure resources with token
           ▼
┌─────────────────────────────────────────────────────────────────┐
│ Azure Resources                                                 │
│                                                                 │
│ Authorization via RBAC:                                         │
│   - Identity: sp-github-fd-fb-apim-dev                         │
│   - Role: Contributor                                           │
│   - Scope: Resource Group rg-sample-privapp-weu                │
│                                                                 │
│ Allowed actions:                                                │
│   ✅ Deploy Bicep templates                                    │
│   ✅ Create/update resources in RG                             │
│   ✅ Access ACR, Web Apps, etc.                                │
│                                                                 │
│ Denied actions:                                                 │
│   ❌ Resources outside RG                                      │
│   ❌ Subscription-level changes                                │
└─────────────────────────────────────────────────────────────────┘
```

## Security Benefits

### 🔒 No Long-Lived Secrets
- Traditional: Service principal password stored in GitHub (valid for months/years)
- OIDC: Short-lived token (valid for 10-15 minutes, workflow duration only)

### 🎯 Scoped Access
- **Repository**: Only `fjgomariz/fd-fb-apim`
- **Environment**: Only `dev` (not staging, prod, or no environment)
- **Resources**: Only `rg-sample-privapp-weu` resource group
- **Forks**: Cannot use credentials (subject won't match)

### 📝 Auditable
All actions logged in Azure Activity Log:
```
Caller: sp-github-fd-fb-apim-dev
Action: Microsoft.Resources/deployments/write
Resource: rg-sample-privapp-weu
Timestamp: 2024-01-14T13:30:00Z
```

### 🔄 Automatic Rotation
No manual credential rotation needed - each workflow run gets a fresh token.

## Subject Format Explained

```
repo:fjgomariz/fd-fb-apim:environment:dev
│    │         │           │            │
│    │         │           │            └─ Environment name
│    │         │           └────────────── Literal "environment:"
│    │         └────────────────────────── Repository name
│    └──────────────────────────────────── Organization/owner
└───────────────────────────────────────── Literal "repo:"
```

This means credentials work ONLY when:
- ✅ Workflow runs in repository `fjgomariz/fd-fb-apim`
- ✅ Job uses environment `dev`
- ❌ Pull request from fork (different repository)
- ❌ Workflow without environment context
- ❌ Different environment (staging, prod)

## Multiple Environments Example

```
Setup Script Runs:
├─ dev     → sp-github-fd-fb-apim-dev     → rg-sample-privapp-dev
├─ staging → sp-github-fd-fb-apim-staging → rg-sample-privapp-staging
└─ prod    → sp-github-fd-fb-apim-prod    → rg-sample-privapp-prod

Each with unique subject:
├─ repo:fjgomariz/fd-fb-apim:environment:dev
├─ repo:fjgomariz/fd-fb-apim:environment:staging
└─ repo:fjgomariz/fd-fb-apim:environment:prod

Same GitHub secrets (differentiated by environment context)
```

## Troubleshooting Flow

```
Workflow fails with "AADSTS70021: No matching federated identity"
                           │
                           ▼
                    Check environment
                           │
              ┌────────────┴────────────┐
              ▼                         ▼
    Environment in workflow?    Environment in GitHub?
    (environment: dev)          (Settings → Environments)
              │                         │
              └────────┬────────────────┘
                       ▼
            Subject matches exactly?
        repo:{org}/{repo}:environment:{env}
                       │
                       ▼
              Run federated cred list:
    az ad app federated-credential list \
      --id <app-id> \
      --query "[].{Name:name, Subject:subject}"
```

## See Also

- [QUICKSTART-OIDC.md](QUICKSTART-OIDC.md) - Quick setup guide
- [scripts/README.md](scripts/README.md) - Script documentation
- [.github/OIDC-SETUP.md](.github/OIDC-SETUP.md) - Detailed setup guide
