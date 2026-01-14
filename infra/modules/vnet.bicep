// Virtual Network module
@description('The name of the virtual network')
param name string

@description('The location for the virtual network')
param location string = resourceGroup().location

@description('The address prefix for the virtual network')
param addressPrefix string = '10.0.0.0/16'

@description('Array of subnet configurations')
param subnets array = []

@description('Tags to apply to the resource')
param tags object = {}

resource vnet 'Microsoft.Network/virtualNetworks@2023-04-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressPrefix
      ]
    }
    subnets: [for subnet in subnets: {
      name: subnet.name
      properties: {
        addressPrefix: subnet.addressPrefix
        delegations: contains(subnet, 'delegations') ? subnet.?delegations : []
        serviceEndpoints: contains(subnet, 'serviceEndpoints') ? subnet.?serviceEndpoints : []
        privateEndpointNetworkPolicies: contains(subnet, 'privateEndpointNetworkPolicies') ? subnet.?privateEndpointNetworkPolicies : 'Disabled'
        privateLinkServiceNetworkPolicies: contains(subnet, 'privateLinkServiceNetworkPolicies') ? subnet.?privateLinkServiceNetworkPolicies : 'Enabled'
      }
    }]
  }
}

@description('The resource ID of the virtual network')
output id string = vnet.id

@description('The name of the virtual network')
output name string = vnet.name

@description('Array of subnet resource IDs')
output subnetIds array = [for (subnet, i) in subnets: vnet.properties.subnets[i].id]

@description('Map of subnet names to their details')
output subnets object = reduce(range(0, length(subnets)), {}, (cur, i) => union(cur, {
  '${subnets[i].name}': {
    id: vnet.properties.subnets[i].id
    name: vnet.properties.subnets[i].name
    addressPrefix: vnet.properties.subnets[i].properties.addressPrefix
  }
}))
