// Private Endpoints module
@description('The location for the private endpoints')
param location string = resourceGroup().location

@description('The subnet resource ID for private endpoints')
param subnetId string

@description('Configuration for web app private endpoints')
param webApps array = []

@description('Configuration for APIM private endpoint')
param apim object = {}

@description('Configuration for Storage private endpoint')
param storage object = {}

@description('Configuration for Key Vault private endpoint')
param keyVault object = {}

@description('Tags to apply to resources')
param tags object = {}

// Private DNS Zones
resource webAppPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = if (length(webApps) > 0) {
  name: 'privatelink.azurewebsites.net'
  location: 'global'
  tags: tags
}

resource apimPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = if (!empty(apim)) {
  name: 'privatelink.azure-api.net'
  location: 'global'
  tags: tags
}

resource blobPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = if (!empty(storage)) {
  name: 'privatelink.blob.${environment().suffixes.storage}'
  location: 'global'
  tags: tags
}

resource keyVaultPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = if (!empty(keyVault)) {
  name: 'privatelink.vaultcore.azure.net'
  location: 'global'
  tags: tags
}

// Get VNet ID from subnet ID
var vnetId = split(subnetId, '/subnets/')[0]

// DNS Zone Virtual Network Links
resource webAppDnsZoneVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if (length(webApps) > 0) {
  parent: webAppPrivateDnsZone
  name: 'webapp-vnet-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetId
    }
  }
}

resource apimDnsZoneVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if (!empty(apim)) {
  parent: apimPrivateDnsZone
  name: 'apim-vnet-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetId
    }
  }
}

resource blobDnsZoneVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if (!empty(storage)) {
  parent: blobPrivateDnsZone
  name: 'blob-vnet-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetId
    }
  }
}

resource keyVaultDnsZoneVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if (!empty(keyVault)) {
  parent: keyVaultPrivateDnsZone
  name: 'keyvault-vnet-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetId
    }
  }
}

// Private Endpoints for Web Apps
resource webAppPrivateEndpoints 'Microsoft.Network/privateEndpoints@2023-04-01' = [for (webApp, i) in webApps: {
  name: '${webApp.name}-pe'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: subnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${webApp.name}-pe-connection'
        properties: {
          privateLinkServiceId: webApp.id
          groupIds: [
            'sites'
          ]
        }
      }
    ]
  }
}]

resource webAppPrivateDnsZoneGroups 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-04-01' = [for (webApp, i) in webApps: if (length(webApps) > 0) {
  parent: webAppPrivateEndpoints[i]
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink-azurewebsites-net'
        properties: {
          privateDnsZoneId: webAppPrivateDnsZone.id
        }
      }
    ]
  }
}]

// Private Endpoint for APIM
resource apimPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-04-01' = if (!empty(apim)) {
  name: '${apim.name}-pe'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: subnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${apim.name}-pe-connection'
        properties: {
          privateLinkServiceId: apim.id
          groupIds: [
            'Gateway'
          ]
        }
      }
    ]
  }
}

resource apimPrivateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-04-01' = if (!empty(apim)) {
  parent: apimPrivateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink-azure-api-net'
        properties: {
          privateDnsZoneId: apimPrivateDnsZone.id
        }
      }
    ]
  }
}

// Private Endpoint for Storage Blob
resource storagePrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-04-01' = if (!empty(storage)) {
  name: '${storage.name}-blob-pe'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: subnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${storage.name}-blob-pe-connection'
        properties: {
          privateLinkServiceId: storage.id
          groupIds: [
            'blob'
          ]
        }
      }
    ]
  }
}

resource storagePrivateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-04-01' = if (!empty(storage)) {
  parent: storagePrivateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink-blob'
        properties: {
          privateDnsZoneId: blobPrivateDnsZone.id
        }
      }
    ]
  }
}

// Private Endpoint for Key Vault
resource keyVaultPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-04-01' = if (!empty(keyVault)) {
  name: '${keyVault.name}-pe'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: subnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${keyVault.name}-pe-connection'
        properties: {
          privateLinkServiceId: keyVault.id
          groupIds: [
            'vault'
          ]
        }
      }
    ]
  }
}

resource keyVaultPrivateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-04-01' = if (!empty(keyVault)) {
  parent: keyVaultPrivateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink-vaultcore-azure-net'
        properties: {
          privateDnsZoneId: keyVaultPrivateDnsZone.id
        }
      }
    ]
  }
}

@description('The resource IDs of the web app private endpoints')
output webAppPrivateEndpointIds array = [for (webApp, i) in webApps: webAppPrivateEndpoints[i].id]

@description('The resource ID of the APIM private endpoint')
output apimPrivateEndpointId string = !empty(apim) ? apimPrivateEndpoint.id : ''

@description('The resource ID of the storage private endpoint')
output storagePrivateEndpointId string = !empty(storage) ? storagePrivateEndpoint.id : ''

@description('The resource ID of the Key Vault private endpoint')
output keyVaultPrivateEndpointId string = !empty(keyVault) ? keyVaultPrivateEndpoint.id : ''
