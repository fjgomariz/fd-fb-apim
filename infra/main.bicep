// Main Bicep template - orchestrates all infrastructure modules
targetScope = 'subscription'

// ===== Parameters =====
@description('The name of the resource group to deploy resources into')
param resourceGroupName string

@description('The Azure region for all resources')
param location string = 'westeurope'

@description('The environment name (dev, test, prod)')
@allowed([
  'dev'
  'test'
  'prod'
])
param environment string = 'dev'

@description('Resource naming configuration')
param names object = {
  acr: 'fdfbapim'
  frontendApp: 'fd-fb-apim-frontend'
  backendApp: 'fd-fb-apim-backend'
  storage: 'fdfbapim'
  apim: 'fd-fb-apim'
  frontdoor: 'fd-fb-apim'
  insights: 'fd-fb-apim'
  law: 'fd-fb-apim'
  kv: 'fd-fb-apim'
  vnet: 'fd-fb-apim'
  appServicePlan: 'fd-fb-apim'
}

@description('APIM publisher email')
param apimPublisherEmail string = 'admin@example.com'

@description('APIM publisher name')
param apimPublisherName string = 'Sample Organization'

@description('APIM SKU')
@allowed([
  'Developer'
  'Premium'
  'StandardV2'
])
param apimSku string = 'Developer'

@description('Container image for frontend app')
param frontendContainerImage string = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'

@description('Container image for backend app')
param backendContainerImage string = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'

@description('Tags to apply to all resources')
param tags object = {
  environment: environment
  project: 'private-by-default'
  managedBy: 'bicep'
}

// ===== Resource Group =====
module resourceGroup 'modules/rg.bicep' = {
  name: 'rg-deployment'
  params: {
    name: resourceGroupName
    location: location
    tags: tags
  }
}

// ===== Networking =====
module vnet 'modules/vnet.bicep' = {
  name: 'vnet-deployment'
  scope: az.resourceGroup(resourceGroup.name)
  params: {
    name: names.vnet
    location: location
    addressPrefix: '10.0.0.0/16'
    subnets: [
      {
        name: 'snet-apim'
        addressPrefix: '10.0.1.0/24'
      }
      {
        name: 'snet-webapps'
        addressPrefix: '10.0.2.0/27'
        delegations: [
          {
            name: 'delegation'
            properties: {
              serviceName: 'Microsoft.Web/serverFarms'
            }
          }
        ]
      }
      {
        name: 'snet-privateendpoints'
        addressPrefix: '10.0.3.0/24'
        privateEndpointNetworkPolicies: 'Disabled'
      }
    ]
    tags: tags
  }
}

// ===== Monitoring =====
module logAnalytics 'modules/log-analytics.bicep' = {
  name: 'law-deployment'
  scope: az.resourceGroup(resourceGroup.name)
  params: {
    name: names.law
    location: location
    sku: 'PerGB2018'
    retentionInDays: 30
    tags: tags
  }
}

module appInsights 'modules/app-insights.bicep' = {
  name: 'appi-deployment'
  scope: az.resourceGroup(resourceGroup.name)
  params: {
    name: names.insights
    location: location
    workspaceId: logAnalytics.outputs.id
    applicationType: 'web'
    tags: tags
  }
}

// ===== Container Registry =====
module acr 'modules/acr.bicep' = {
  name: 'acr-deployment'
  scope: az.resourceGroup(resourceGroup.name)
  params: {
    name: names.acr
    location: location
    sku: 'Premium'
    adminUserEnabled: false
    publicNetworkAccess: 'Enabled' // Can be changed to Disabled after adding private endpoint
    tags: tags
  }
}

// ===== App Service Plan =====
module appServicePlan 'modules/appservice-plan.bicep' = {
  name: 'asp-deployment'
  scope: az.resourceGroup(resourceGroup.name)
  params: {
    name: names.appServicePlan
    location: location
    skuName: 'P1V3'
    skuCapacity: 1
    kind: 'linux'
    reserved: true
    tags: tags
  }
}

// ===== Web Apps =====
module frontendApp 'modules/webapp.bicep' = {
  name: 'frontend-app-deployment'
  scope: az.resourceGroup(resourceGroup.name)
  params: {
    name: names.frontendApp
    location: location
    appServicePlanId: appServicePlan.outputs.id
    containerImageName: frontendContainerImage
    acrLoginServer: acr.outputs.loginServer
    enableSystemAssignedIdentity: true
    enableVNetIntegration: true
    vnetSubnetId: vnet.outputs.subnets['snet-webapps'].id
    appSettings: {
      APPLICATIONINSIGHTS_CONNECTION_STRING: appInsights.outputs.connectionString
      ApplicationInsightsAgent_EXTENSION_VERSION: '~3'
    }
    tags: tags
  }
}

module backendApp 'modules/webapp.bicep' = {
  name: 'backend-app-deployment'
  scope: az.resourceGroup(resourceGroup.name)
  params: {
    name: names.backendApp
    location: location
    appServicePlanId: appServicePlan.outputs.id
    containerImageName: backendContainerImage
    acrLoginServer: acr.outputs.loginServer
    enableSystemAssignedIdentity: true
    enableVNetIntegration: true
    vnetSubnetId: vnet.outputs.subnets['snet-webapps'].id
    appSettings: {
      APPLICATIONINSIGHTS_CONNECTION_STRING: appInsights.outputs.connectionString
      ApplicationInsightsAgent_EXTENSION_VERSION: '~3'
      AZ_STORAGE_NAME: names.storage
      AZ_BLOB_CONTAINER: 'uploads'
    }
    tags: tags
  }
}

// ===== Storage Account =====
module storage 'modules/storage.bicep' = {
  name: 'storage-deployment'
  scope: az.resourceGroup(resourceGroup.name)
  params: {
    name: names.storage
    location: location
    sku: 'Standard_LRS'
    containerName: 'uploads'
    enableBlobSoftDelete: true
    blobSoftDeleteRetentionDays: 7
    publicNetworkAccess: 'Disabled'
    minimumTlsVersion: 'TLS1_2'
    tags: tags
  }
}

// ===== API Management =====
module apim 'modules/apim.bicep' = {
  name: 'apim-deployment'
  scope: az.resourceGroup(resourceGroup.name)
  params: {
    name: names.apim
    location: location
    sku: apimSku
    skuCapacity: 1
    publisherEmail: apimPublisherEmail
    publisherName: apimPublisherName
    appInsightsId: appInsights.outputs.id
    appInsightsInstrumentationKey: appInsights.outputs.instrumentationKey
    virtualNetworkType: 'Internal'
    subnetId: vnet.outputs.subnets['snet-apim'].id
    tags: tags
  }
}

// ===== Key Vault =====
module keyVault 'modules/keyvault.bicep' = {
  name: 'kv-deployment'
  scope: az.resourceGroup(resourceGroup.name)
  params: {
    name: names.kv
    location: location
    sku: 'standard'
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
    enablePurgeProtection: true
    publicNetworkAccess: 'Disabled'
    networkAclsDefaultAction: 'Deny'
    tags: tags
  }
}

// ===== Private Endpoints =====
module privateEndpoints 'modules/private-endpoints.bicep' = {
  name: 'pe-deployment'
  scope: az.resourceGroup(resourceGroup.name)
  params: {
    location: location
    subnetId: vnet.outputs.subnets['snet-privateendpoints'].id
    webApps: [
      {
        name: frontendApp.outputs.name
        id: frontendApp.outputs.id
      }
      {
        name: backendApp.outputs.name
        id: backendApp.outputs.id
      }
    ]
    apim: {
      name: apim.outputs.name
      id: apim.outputs.id
    }
    storage: {
      name: storage.outputs.name
      id: storage.outputs.id
    }
    keyVault: {
      name: keyVault.outputs.name
      id: keyVault.outputs.id
    }
    tags: tags
  }
}

// ===== Front Door =====
module frontDoor 'modules/frontdoor.bicep' = {
  name: 'fd-deployment'
  scope: az.resourceGroup(resourceGroup.name)
  params: {
    name: names.frontdoor
    sku: 'Premium_AzureFrontDoor'
    frontendHostname: frontendApp.outputs.hostname
    frontendAppId: frontendApp.outputs.id
    apimHostname: replace(apim.outputs.gatewayUrl, 'https://', '')
    apimId: apim.outputs.id
    enableWaf: true
    wafMode: 'Prevention'
    customBlockList: []
    tags: tags
  }
  dependsOn: [
    privateEndpoints // Wait for private endpoints to be created
  ]
}

// ===== RBAC Assignments =====
// Note: RBAC assignments need to be in a separate module or at resource group scope
// For simplicity, we'll define them here with proper resource group scope

module rbacAssignments 'modules/rbac-assignments.bicep' = {
  name: 'rbac-deployment'
  scope: az.resourceGroup(resourceGroup.name)
  params: {
    frontendAppPrincipalId: frontendApp.outputs.principalId
    backendAppPrincipalId: backendApp.outputs.principalId
    acrId: acr.outputs.id
    storageId: storage.outputs.id
  }
}

// ===== Outputs =====
@description('The resource group name')
output resourceGroupName string = resourceGroup.name

@description('The Front Door endpoint URL')
output frontDoorEndpoint string = frontDoor.outputs.endpointUrl

@description('The frontend web app hostname')
output frontendHostname string = frontendApp.outputs.hostname

@description('The backend web app hostname')
output backendHostname string = backendApp.outputs.hostname

@description('The APIM gateway URL')
output apimGatewayUrl string = apim.outputs.gatewayUrl

@description('The ACR login server')
output acrLoginServer string = acr.outputs.loginServer

@description('The Application Insights connection string')
output appInsightsConnectionString string = appInsights.outputs.connectionString

@description('The storage account name')
output storageAccountName string = storage.outputs.name

@description('The Key Vault URI')
output keyVaultUri string = keyVault.outputs.vaultUri
