// Azure Container Registry module
@description('The name of the Azure Container Registry')
param name string

@description('The location for the Azure Container Registry')
param location string = resourceGroup().location

@description('The SKU of the Azure Container Registry')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param sku string = 'Premium'

@description('Enable admin user')
param adminUserEnabled bool = false

@description('Enable public network access')
param publicNetworkAccess string = 'Enabled'

@description('Tags to apply to the resource')
param tags object = {}

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: sku
  }
  properties: {
    adminUserEnabled: adminUserEnabled
    publicNetworkAccess: publicNetworkAccess
    networkRuleBypassOptions: 'AzureServices'
    policies: {
      retentionPolicy: {
        days: 7
        status: 'enabled'
      }
    }
  }
}

@description('The resource ID of the Azure Container Registry')
output id string = containerRegistry.id

@description('The name of the Azure Container Registry')
output name string = containerRegistry.name

@description('The login server of the Azure Container Registry')
output loginServer string = containerRegistry.properties.loginServer
