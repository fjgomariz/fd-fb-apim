// API Management module
@description('The name of the API Management service')
param name string

@description('The location for the API Management service')
param location string = resourceGroup().location

@description('The SKU of the API Management service')
@allowed([
  'Developer'
  'Premium'
  'StandardV2'
])
param sku string = 'Developer'

@description('The SKU capacity')
param skuCapacity int = 1

@description('The email address of the publisher')
param publisherEmail string

@description('The name of the publisher organization')
param publisherName string

@description('The resource ID of the Application Insights')
param appInsightsId string = ''

@description('The instrumentation key of Application Insights')
param appInsightsInstrumentationKey string = ''

@description('Virtual network type')
@allowed([
  'None'
  'Internal'
  'External'
])
param virtualNetworkType string = 'Internal'

@description('The subnet resource ID for APIM (required for Internal/External VNet mode)')
param subnetId string = ''

@description('Tags to apply to the resource')
param tags object = {}

resource apim 'Microsoft.ApiManagement/service@2023-03-01-preview' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: sku
    capacity: skuCapacity
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    publisherEmail: publisherEmail
    publisherName: publisherName
    virtualNetworkType: virtualNetworkType
    virtualNetworkConfiguration: virtualNetworkType != 'None' && !empty(subnetId) ? {
      subnetResourceId: subnetId
    } : null
    customProperties: {
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls10': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls11': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls10': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls11': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Protocols.Server.Http2': 'True'
    }
  }
}

// Configure Application Insights logger if provided
resource logger 'Microsoft.ApiManagement/service/loggers@2023-03-01-preview' = if (!empty(appInsightsId)) {
  parent: apim
  name: 'applicationinsights'
  properties: {
    loggerType: 'applicationInsights'
    resourceId: appInsightsId
    credentials: {
      instrumentationKey: appInsightsInstrumentationKey
    }
  }
}

// Enable Application Insights diagnostic settings
resource diagnostics 'Microsoft.ApiManagement/service/diagnostics@2023-03-01-preview' = if (!empty(appInsightsId)) {
  parent: apim
  name: 'applicationinsights'
  properties: {
    loggerId: logger.id
    alwaysLog: 'allErrors'
    sampling: {
      samplingType: 'fixed'
      percentage: 100
    }
    frontend: {
      request: {
        dataMasking: {
          headers: []
          queryParams: []
        }
      }
      response: {
        dataMasking: {
          headers: []
          queryParams: []
        }
      }
    }
    backend: {
      request: {
        dataMasking: {
          headers: []
          queryParams: []
        }
      }
      response: {
        dataMasking: {
          headers: []
          queryParams: []
        }
      }
    }
  }
}

@description('The resource ID of the API Management service')
output id string = apim.id

@description('The name of the API Management service')
output name string = apim.name

@description('The gateway URL of the API Management service')
output gatewayUrl string = apim.properties.gatewayUrl

@description('The principal ID of the system-assigned managed identity')
output principalId string = apim.identity.principalId

@description('The private IP addresses (for Internal VNet mode)')
output privateIpAddresses array = virtualNetworkType == 'Internal' ? apim.properties.privateIPAddresses : []
