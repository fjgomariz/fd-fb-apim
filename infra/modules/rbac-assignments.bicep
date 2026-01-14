// RBAC Role Assignments module
@description('The principal ID of the frontend app managed identity')
param frontendAppPrincipalId string

@description('The principal ID of the backend app managed identity')
param backendAppPrincipalId string

@description('The resource ID of the Azure Container Registry')
param acrId string

@description('The resource ID of the Storage Account')
param storageId string

// ACR Pull role definition ID
var acrPullRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')

// Storage Blob Data Contributor role definition ID
var storageBlobDataContributorRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')

// Grant ACR Pull role to frontend app
resource frontendAcrPullRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acrId, frontendAppPrincipalId, 'AcrPull')
  scope: acr
  properties: {
    roleDefinitionId: acrPullRoleId
    principalId: frontendAppPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// Grant ACR Pull role to backend app
resource backendAcrPullRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acrId, backendAppPrincipalId, 'AcrPull')
  scope: acr
  properties: {
    roleDefinitionId: acrPullRoleId
    principalId: backendAppPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// Grant Storage Blob Data Contributor to backend app
resource backendStorageRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageId, backendAppPrincipalId, 'StorageBlobDataContributor')
  scope: storage
  properties: {
    roleDefinitionId: storageBlobDataContributorRoleId
    principalId: backendAppPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// Reference existing resources for scope
resource acr 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' existing = {
  name: last(split(acrId, '/'))
}

resource storage 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: last(split(storageId, '/'))
}

@description('Role assignments created successfully')
output status string = 'RBAC assignments completed'
