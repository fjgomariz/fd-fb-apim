#!/bin/bash
set -e

# Simple script to set up GitHub OIDC for Azure authentication
# Usage: ./scripts/setup-oidc.sh <github-org> <github-repo> <resource-group-name> [subscription-id]

if [ $# -lt 3 ]; then
    echo "Usage: $0 <github-org> <github-repo> <resource-group-name> [subscription-id]"
    echo ""
    echo "Example:"
    echo "  $0 fjgomariz fd-fb-apim rg-sample-privapp-weu"
    exit 1
fi

GITHUB_ORG="$1"
GITHUB_REPO="$2"
RESOURCE_GROUP="$3"
SUBSCRIPTION_ID="${4:-$(az account show --query id -o tsv)}"

SP_NAME="sp-github-${GITHUB_REPO}"

echo "Setting up GitHub OIDC for Azure..."
echo "GitHub: ${GITHUB_ORG}/${GITHUB_REPO}"
echo "Resource Group: ${RESOURCE_GROUP}"
echo "Subscription: ${SUBSCRIPTION_ID}"
echo ""

# Set subscription
az account set --subscription "$SUBSCRIPTION_ID"
TENANT_ID=$(az account show --query tenantId -o tsv)

# Create service principal or get existing
echo "Creating service principal: ${SP_NAME}"
EXISTING_SP=$(az ad sp list --display-name "$SP_NAME" --query "[0].appId" -o tsv 2>/dev/null || echo "")

if [ -n "$EXISTING_SP" ]; then
    echo "Using existing service principal: $EXISTING_SP"
    APP_ID="$EXISTING_SP"
else
    # Create resource group if it doesn't exist
    if ! az group show --name "$RESOURCE_GROUP" &> /dev/null; then
        echo "Creating resource group: $RESOURCE_GROUP"
        az group create --name "$RESOURCE_GROUP" --location "westeurope"
    fi
    
    # Create service principal with Contributor role on resource group
    SP_OUTPUT=$(az ad sp create-for-rbac \
        --name "$SP_NAME" \
        --role Contributor \
        --scopes "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP" \
        --query "appId" -o tsv)
    APP_ID="$SP_OUTPUT"
    echo "Created service principal: $APP_ID"
fi

# Add federated credential
CRED_NAME="github-${GITHUB_REPO}"
SUBJECT="repo:${GITHUB_ORG}/${GITHUB_REPO}:ref:refs/heads/main"

echo "Adding federated credential..."
az ad app federated-credential delete --id "$APP_ID" --federated-credential-id "$CRED_NAME" 2>/dev/null || true

az ad app federated-credential create \
    --id "$APP_ID" \
    --parameters "{
        \"name\": \"$CRED_NAME\",
        \"issuer\": \"https://token.actions.githubusercontent.com\",
        \"subject\": \"$SUBJECT\",
        \"audiences\": [\"api://AzureADTokenExchange\"]
    }"

echo ""
echo "======================================================================"
echo "Setup Complete!"
echo "======================================================================"
echo ""
echo "Add these secrets to your GitHub repository:"
echo "https://github.com/${GITHUB_ORG}/${GITHUB_REPO}/settings/secrets/actions"
echo ""
echo "AZURE_CLIENT_ID:        ${APP_ID}"
echo "AZURE_TENANT_ID:        ${TENANT_ID}"
echo "AZURE_SUBSCRIPTION_ID:  ${SUBSCRIPTION_ID}"
echo ""
echo "======================================================================"
