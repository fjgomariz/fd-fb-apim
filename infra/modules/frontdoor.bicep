// Azure Front Door Premium module
@description('The name of the Front Door profile')
param name string

@description('The SKU of the Front Door')
@allowed([
  'Standard_AzureFrontDoor'
  'Premium_AzureFrontDoor'
])
param sku string = 'Premium_AzureFrontDoor'

@description('Frontend Web App hostname for origin')
param frontendHostname string

@description('Frontend Web App resource ID for Private Link')
param frontendAppId string

@description('APIM gateway hostname for origin')
param apimHostname string

@description('APIM resource ID for Private Link')
param apimId string

@description('Enable WAF policy')
param enableWaf bool = true

@description('WAF mode')
@allowed([
  'Detection'
  'Prevention'
])
param wafMode string = 'Prevention'

@description('Custom block list (IP addresses or CIDR ranges)')
param customBlockList array = []

@description('Tags to apply to resources')
param tags object = {}

// WAF Policy
resource wafPolicy 'Microsoft.Network/FrontDoorWebApplicationFirewallPolicies@2022-05-01' = if (enableWaf) {
  name: '${replace(name, '-', '')}wafpolicy'
  location: 'Global'
  tags: tags
  sku: {
    name: sku
  }
  properties: {
    policySettings: {
      enabledState: 'Enabled'
      mode: wafMode
      requestBodyCheck: 'Enabled'
    }
    managedRules: {
      managedRuleSets: [
        {
          ruleSetType: 'Microsoft_DefaultRuleSet'
          ruleSetVersion: '2.1'
          ruleSetAction: 'Block'
        }
        {
          ruleSetType: 'Microsoft_BotManagerRuleSet'
          ruleSetVersion: '1.0'
        }
      ]
    }
    customRules: {
      rules: length(customBlockList) > 0 ? [
        {
          name: 'CustomBlockRule'
          priority: 100
          ruleType: 'MatchRule'
          action: 'Block'
          matchConditions: [
            {
              matchVariable: 'RemoteAddr'
              operator: 'IPMatch'
              matchValue: customBlockList
            }
          ]
        }
      ] : []
    }
  }
}

// Front Door Profile
resource frontDoorProfile 'Microsoft.Cdn/profiles@2023-05-01' = {
  name: name
  location: 'Global'
  tags: tags
  sku: {
    name: sku
  }
}

// Security Policy (link WAF to endpoint)
resource securityPolicy 'Microsoft.Cdn/profiles/securityPolicies@2023-05-01' = if (enableWaf) {
  parent: frontDoorProfile
  name: 'security-policy'
  properties: {
    parameters: {
      type: 'WebApplicationFirewall'
      wafPolicy: {
        id: wafPolicy.id
      }
      associations: [
        {
          domains: [
            {
              id: frontDoorEndpoint.id
            }
          ]
          patternsToMatch: [
            '/*'
          ]
        }
      ]
    }
  }
}

// Front Door Endpoint
resource frontDoorEndpoint 'Microsoft.Cdn/profiles/afdEndpoints@2023-05-01' = {
  parent: frontDoorProfile
  name: '${name}-endpoint'
  location: 'Global'
  properties: {
    enabledState: 'Enabled'
  }
}

// Origin Group for Frontend
resource frontendOriginGroup 'Microsoft.Cdn/profiles/originGroups@2023-05-01' = {
  parent: frontDoorProfile
  name: 'frontend-origin-group'
  properties: {
    loadBalancingSettings: {
      sampleSize: 4
      successfulSamplesRequired: 3
      additionalLatencyInMilliseconds: 50
    }
    healthProbeSettings: {
      probePath: '/'
      probeRequestType: 'HEAD'
      probeProtocol: 'Https'
      probeIntervalInSeconds: 100
    }
  }
}

// Origin for Frontend (Private Link)
resource frontendOrigin 'Microsoft.Cdn/profiles/originGroups/origins@2023-05-01' = {
  parent: frontendOriginGroup
  name: 'frontend-origin'
  properties: {
    hostName: frontendHostname
    httpPort: 80
    httpsPort: 443
    originHostHeader: frontendHostname
    priority: 1
    weight: 1000
    enabledState: 'Enabled'
    sharedPrivateLinkResource: sku == 'Premium_AzureFrontDoor' ? {
      privateLink: {
        id: frontendAppId
      }
      privateLinkLocation: resourceGroup().location
      groupId: 'sites'
      requestMessage: 'Private link connection from Front Door'
    } : null
  }
}

// Origin Group for APIM
resource apimOriginGroup 'Microsoft.Cdn/profiles/originGroups@2023-05-01' = {
  parent: frontDoorProfile
  name: 'apim-origin-group'
  properties: {
    loadBalancingSettings: {
      sampleSize: 4
      successfulSamplesRequired: 3
      additionalLatencyInMilliseconds: 50
    }
    healthProbeSettings: {
      probePath: '/status-0123456789abcdef'
      probeRequestType: 'HEAD'
      probeProtocol: 'Https'
      probeIntervalInSeconds: 100
    }
  }
}

// Origin for APIM (Private Link)
resource apimOrigin 'Microsoft.Cdn/profiles/originGroups/origins@2023-05-01' = {
  parent: apimOriginGroup
  name: 'apim-origin'
  properties: {
    hostName: apimHostname
    httpPort: 80
    httpsPort: 443
    originHostHeader: apimHostname
    priority: 1
    weight: 1000
    enabledState: 'Enabled'
    sharedPrivateLinkResource: sku == 'Premium_AzureFrontDoor' ? {
      privateLink: {
        id: apimId
      }
      privateLinkLocation: resourceGroup().location
      groupId: 'Gateway'
      requestMessage: 'Private link connection from Front Door'
    } : null
  }
}

// Route for frontend (/)
resource frontendRoute 'Microsoft.Cdn/profiles/afdEndpoints/routes@2023-05-01' = {
  parent: frontDoorEndpoint
  name: 'frontend-route'
  properties: {
    originGroup: {
      id: frontendOriginGroup.id
    }
    supportedProtocols: [
      'Https'
    ]
    patternsToMatch: [
      '/'
      '/*'
    ]
    forwardingProtocol: 'HttpsOnly'
    linkToDefaultDomain: 'Enabled'
    httpsRedirect: 'Enabled'
  }
  dependsOn: [
    frontendOrigin
  ]
}

// Route for APIM (/api/*)
resource apimRoute 'Microsoft.Cdn/profiles/afdEndpoints/routes@2023-05-01' = {
  parent: frontDoorEndpoint
  name: 'apim-route'
  properties: {
    originGroup: {
      id: apimOriginGroup.id
    }
    supportedProtocols: [
      'Https'
    ]
    patternsToMatch: [
      '/api/*'
    ]
    forwardingProtocol: 'HttpsOnly'
    linkToDefaultDomain: 'Enabled'
    httpsRedirect: 'Enabled'
  }
  dependsOn: [
    apimOrigin
    frontendRoute // Ensure routes don't conflict
  ]
}

@description('The resource ID of the Front Door profile')
output id string = frontDoorProfile.id

@description('The name of the Front Door profile')
output name string = frontDoorProfile.name

@description('The Front Door endpoint hostname')
output endpointHostname string = frontDoorEndpoint.properties.hostName

@description('The resource ID of the WAF policy')
output wafPolicyId string = enableWaf ? wafPolicy.id : ''

@description('The Front Door endpoint URL')
output endpointUrl string = 'https://${frontDoorEndpoint.properties.hostName}'
