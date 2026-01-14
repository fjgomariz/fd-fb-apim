// App Service Plan module
@description('The name of the App Service Plan')
param name string

@description('The location for the App Service Plan')
param location string = resourceGroup().location

@description('The SKU name for the App Service Plan')
param skuName string = 'P1V3'

@description('The SKU capacity (number of instances)')
param skuCapacity int = 1

@description('Kind of App Service Plan - linux for Linux containers')
param kind string = 'linux'

@description('Reserved flag - must be true for Linux')
param reserved bool = true

@description('Tags to apply to the resource')
param tags object = {}

resource appServicePlan 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: name
  location: location
  tags: tags
  kind: kind
  sku: {
    name: skuName
    capacity: skuCapacity
  }
  properties: {
    reserved: reserved
  }
}

@description('The resource ID of the App Service Plan')
output id string = appServicePlan.id

@description('The name of the App Service Plan')
output name string = appServicePlan.name
