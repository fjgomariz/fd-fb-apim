// Application Insights module
@description('The name of the Application Insights resource')
param name string

@description('The location for the Application Insights resource')
param location string = resourceGroup().location

@description('The resource ID of the Log Analytics workspace')
param workspaceId string

@description('Application type')
@allowed([
  'web'
  'other'
])
param applicationType string = 'web'

@description('Tags to apply to the resource')
param tags object = {}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: name
  location: location
  tags: tags
  kind: applicationType
  properties: {
    Application_Type: applicationType
    WorkspaceResourceId: workspaceId
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

@description('The resource ID of the Application Insights resource')
output id string = appInsights.id

@description('The instrumentation key of the Application Insights resource')
output instrumentationKey string = appInsights.properties.InstrumentationKey

@description('The connection string of the Application Insights resource')
output connectionString string = appInsights.properties.ConnectionString

@description('The name of the Application Insights resource')
output name string = appInsights.name
