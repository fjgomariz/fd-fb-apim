#!/bin/bash
set -e

# Script to create Azure Service Principal with GitHub OIDC federated credentials
# This enables GitHub Actions to authenticate to Azure without storing secrets

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored messages
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if required tools are installed
check_prerequisites() {
    print_info "Checking prerequisites..."
    
    if ! command -v az &> /dev/null; then
        print_error "Azure CLI (az) is not installed. Please install it from https://docs.microsoft.com/cli/azure/install-azure-cli"
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        print_error "jq is not installed. Please install it (e.g., 'apt-get install jq' or 'brew install jq')"
        exit 1
    fi
    
    print_info "Prerequisites check passed"
}

# Parse command line arguments
parse_arguments() {
    if [ $# -lt 4 ]; then
        echo "Usage: $0 <github-org> <github-repo> <environment> <resource-group-name> [subscription-id]"
        echo ""
        echo "Arguments:"
        echo "  github-org          GitHub organization or username (e.g., 'fjgomariz')"
        echo "  github-repo         GitHub repository name (e.g., 'fd-fb-apim')"
        echo "  environment         GitHub environment name (e.g., 'dev', 'staging', 'prod')"
        echo "  resource-group-name Azure resource group name to grant Contributor access"
        echo "  subscription-id     (Optional) Azure subscription ID. Uses current subscription if not provided"
        echo ""
        echo "Example:"
        echo "  $0 fjgomariz fd-fb-apim dev rg-sample-privapp-weu"
        exit 1
    fi
    
    GITHUB_ORG="$1"
    GITHUB_REPO="$2"
    GITHUB_ENV="$3"
    RESOURCE_GROUP="$4"
    SUBSCRIPTION_ID="${5:-}"
    
    # If subscription ID not provided, use current subscription
    if [ -z "$SUBSCRIPTION_ID" ]; then
        SUBSCRIPTION_ID=$(az account show --query id -o tsv)
        print_info "Using current subscription: $SUBSCRIPTION_ID"
    fi
    
    # Set other variables
    SP_NAME="sp-github-${GITHUB_REPO}-${GITHUB_ENV}"
    FEDERATED_CRED_NAME="github-${GITHUB_REPO}-${GITHUB_ENV}"
}

# Login check
check_azure_login() {
    print_info "Checking Azure CLI login status..."
    
    if ! az account show &> /dev/null; then
        print_error "Not logged in to Azure CLI. Please run 'az login' first"
        exit 1
    fi
    
    # Set the subscription
    az account set --subscription "$SUBSCRIPTION_ID"
    
    TENANT_ID=$(az account show --query tenantId -o tsv)
    print_info "Tenant ID: $TENANT_ID"
    print_info "Subscription ID: $SUBSCRIPTION_ID"
}

# Create or get service principal
create_service_principal() {
    print_info "Creating service principal: $SP_NAME"
    
    # Check if service principal already exists
    EXISTING_SP=$(az ad sp list --display-name "$SP_NAME" --query "[0].appId" -o tsv 2>/dev/null || echo "")
    
    if [ -n "$EXISTING_SP" ]; then
        print_warning "Service principal '$SP_NAME' already exists with App ID: $EXISTING_SP"
        print_info "Using existing service principal"
        APP_ID="$EXISTING_SP"
        SP_OBJECT_ID=$(az ad sp show --id "$APP_ID" --query id -o tsv)
    else
        # Create new service principal
        print_info "Creating new service principal..."
        
        # Create the service principal without role assignment (we'll add it later)
        SP_OUTPUT=$(az ad sp create-for-rbac --name "$SP_NAME" --role Contributor --scopes "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP" --query "{appId:appId, objectId:id}" -o json)
        
        APP_ID=$(echo "$SP_OUTPUT" | jq -r '.appId')
        
        # Get the service principal object ID
        SP_OBJECT_ID=$(az ad sp show --id "$APP_ID" --query id -o tsv)
        
        print_info "Service principal created successfully"
    fi
    
    print_info "Application (client) ID: $APP_ID"
    print_info "Service principal object ID: $SP_OBJECT_ID"
}

# Ensure resource group exists and grant Contributor role
grant_permissions() {
    print_info "Checking resource group: $RESOURCE_GROUP"
    
    # Check if resource group exists, if not create it
    if ! az group show --name "$RESOURCE_GROUP" &> /dev/null; then
        print_warning "Resource group '$RESOURCE_GROUP' does not exist"
        read -p "Do you want to create it? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            # Get default location or ask user
            DEFAULT_LOCATION="westeurope"
            read -p "Enter location (default: $DEFAULT_LOCATION): " LOCATION
            LOCATION=${LOCATION:-$DEFAULT_LOCATION}
            
            az group create --name "$RESOURCE_GROUP" --location "$LOCATION"
            print_info "Resource group created"
        else
            print_error "Resource group is required. Exiting."
            exit 1
        fi
    fi
    
    # Grant Contributor role on the resource group
    print_info "Granting Contributor role on resource group..."
    
    # Check if role assignment already exists
    EXISTING_ROLE=$(az role assignment list --assignee "$APP_ID" --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP" --role "Contributor" --query "[0].id" -o tsv 2>/dev/null || echo "")
    
    if [ -n "$EXISTING_ROLE" ]; then
        print_info "Contributor role already assigned"
    else
        az role assignment create \
            --assignee "$APP_ID" \
            --role "Contributor" \
            --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP"
        
        print_info "Contributor role assigned successfully"
    fi
}

# Create federated credential for GitHub OIDC
create_federated_credential() {
    print_info "Creating federated credential for GitHub OIDC..."
    
    # Subject for GitHub environment
    SUBJECT="repo:${GITHUB_ORG}/${GITHUB_REPO}:environment:${GITHUB_ENV}"
    
    # Check if federated credential already exists
    EXISTING_CRED=$(az ad app federated-credential list --id "$APP_ID" --query "[?name=='$FEDERATED_CRED_NAME'].name" -o tsv 2>/dev/null || echo "")
    
    if [ -n "$EXISTING_CRED" ]; then
        print_warning "Federated credential '$FEDERATED_CRED_NAME' already exists"
        print_info "Deleting existing credential and recreating..."
        az ad app federated-credential delete --id "$APP_ID" --federated-credential-id "$FEDERATED_CRED_NAME"
    fi
    
    # Create the federated credential
    az ad app federated-credential create \
        --id "$APP_ID" \
        --parameters "{
            \"name\": \"$FEDERATED_CRED_NAME\",
            \"issuer\": \"https://token.actions.githubusercontent.com\",
            \"subject\": \"$SUBJECT\",
            \"description\": \"GitHub OIDC for ${GITHUB_ORG}/${GITHUB_REPO} in ${GITHUB_ENV} environment\",
            \"audiences\": [
                \"api://AzureADTokenExchange\"
            ]
        }"
    
    print_info "Federated credential created successfully"
    print_info "Subject: $SUBJECT"
}

# Output configuration for GitHub
output_configuration() {
    echo ""
    echo "======================================================================"
    echo "GitHub OIDC Setup Complete!"
    echo "======================================================================"
    echo ""
    echo "Add the following secrets to your GitHub repository:"
    echo "Repository: https://github.com/${GITHUB_ORG}/${GITHUB_REPO}/settings/secrets/actions"
    echo ""
    echo "Secret Name                | Value"
    echo "---------------------------|--------------------------------------"
    echo "AZURE_CLIENT_ID            | ${APP_ID}"
    echo "AZURE_TENANT_ID            | ${TENANT_ID}"
    echo "AZURE_SUBSCRIPTION_ID      | ${SUBSCRIPTION_ID}"
    echo ""
    echo "======================================================================"
    echo ""
    echo "GitHub Environment Configuration:"
    echo "- Create an environment named: ${GITHUB_ENV}"
    echo "- Path: https://github.com/${GITHUB_ORG}/${GITHUB_REPO}/settings/environments"
    echo ""
    echo "======================================================================"
    echo ""
    echo "Example workflow configuration:"
    echo ""
    cat << 'EOF'
jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: dev  # Use the environment name you configured
    permissions:
      id-token: write
      contents: read
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Azure Login with OIDC
        uses: azure/login@v2
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
EOF
    echo ""
    echo "======================================================================"
}

# Main execution
main() {
    echo "======================================================================"
    echo "Azure Service Principal Setup for GitHub OIDC"
    echo "======================================================================"
    echo ""
    
    check_prerequisites
    parse_arguments "$@"
    check_azure_login
    create_service_principal
    grant_permissions
    create_federated_credential
    output_configuration
    
    print_info "Setup completed successfully!"
}

# Run main function
main "$@"
