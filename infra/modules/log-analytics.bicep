// Log Analytics Workspace module
@description('The name of the Log Analytics workspace')
param name string

@description('The location for the Log Analytics workspace')
param location string = resourceGroup().location

@description('The SKU of the Log Analytics workspace')
@allowed([
  'PerGB2018'
  'Free'
  'Standalone'
  'PerNode'
  'Premium'
])
param sku string = 'PerGB2018'

@description('The retention period in days')
@minValue(30)
@maxValue(730)
param retentionInDays int = 30

@description('Tags to apply to the resource')
param tags object = {}

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    sku: {
      name: sku
    }
    retentionInDays: retentionInDays
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

@description('The resource ID of the Log Analytics workspace')
output id string = logAnalyticsWorkspace.id

@description('The workspace ID (customer ID) of the Log Analytics workspace')
output workspaceId string = logAnalyticsWorkspace.properties.customerId

@description('The name of the Log Analytics workspace')
output name string = logAnalyticsWorkspace.name
