// Resource Group module
targetScope = 'subscription'

@description('The name of the resource group')
param name string

@description('The location for the resource group')
param location string

@description('Tags to apply to the resource group')
param tags object = {}

resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: name
  location: location
  tags: tags
}

@description('The resource ID of the resource group')
output id string = resourceGroup.id

@description('The name of the resource group')
output name string = resourceGroup.name

@description('The location of the resource group')
output location string = resourceGroup.location
