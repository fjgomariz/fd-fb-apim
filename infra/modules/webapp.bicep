// Web App module - generic container web app
@description('The name of the Web App')
param name string

@description('The location for the Web App')
param location string = resourceGroup().location

@description('The resource ID of the App Service Plan')
param appServicePlanId string

@description('The container image name and tag (e.g., myregistry.azurecr.io/myapp:latest)')
param containerImageName string

@description('The Azure Container Registry login server')
param acrLoginServer string

@description('Enable system-assigned managed identity')
param enableSystemAssignedIdentity bool = true

@description('Application settings as key-value pairs')
param appSettings object = {}

@description('Enable VNet integration')
param enableVNetIntegration bool = false

@description('The subnet resource ID for VNet integration (required if enableVNetIntegration is true)')
param vnetSubnetId string = ''

@description('HTTPS only')
param httpsOnly bool = true

@description('Tags to apply to the resource')
param tags object = {}

// Convert appSettings object to array format required by the API
var appSettingsArray = [for key in items(appSettings): {
  name: key.key
  value: key.value
}]

// Add required settings for ACR with managed identity
var containerSettings = [
  {
    name: 'DOCKER_REGISTRY_SERVER_URL'
    value: 'https://${acrLoginServer}'
  }
  {
    name: 'WEBSITES_ENABLE_APP_SERVICE_STORAGE'
    value: 'false'
  }
]

var allSettings = union(containerSettings, appSettingsArray)

resource webApp 'Microsoft.Web/sites@2022-09-01' = {
  name: name
  location: location
  tags: tags
  kind: 'app,linux,container'
  identity: enableSystemAssignedIdentity ? {
    type: 'SystemAssigned'
  } : null
  properties: {
    serverFarmId: appServicePlanId
    httpsOnly: httpsOnly
    siteConfig: {
      linuxFxVersion: 'DOCKER|${containerImageName}'
      acrUseManagedIdentityCreds: enableSystemAssignedIdentity
      alwaysOn: true
      http20Enabled: true
      minTlsVersion: '1.2'
      ftpsState: 'Disabled'
      appSettings: allSettings
    }
    virtualNetworkSubnetId: enableVNetIntegration ? vnetSubnetId : null
  }
}

@description('The resource ID of the Web App')
output id string = webApp.id

@description('The name of the Web App')
output name string = webApp.name

@description('The default hostname of the Web App')
output hostname string = webApp.properties.defaultHostName

@description('The principal ID of the system-assigned managed identity')
output principalId string = enableSystemAssignedIdentity ? webApp.identity.principalId : ''

@description('The tenant ID of the system-assigned managed identity')
output tenantId string = enableSystemAssignedIdentity ? webApp.identity.tenantId : ''
