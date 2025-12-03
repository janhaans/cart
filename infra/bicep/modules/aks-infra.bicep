// aks-infra.bicep
targetScope = 'resourceGroup'

@description('Azure region for all resources')
param location string

@description('Short project name used for resource naming')
param projectName string

@description('Deployment environment tag/value (e.g. dev, test)')
param environment string

@description('AKS system node count')
param nodeCount int

@description('AKS VM size for system node pool')
param nodeVmSize string

@description('Enable AKS monitoring via Log Analytics')
param enableMonitoring bool

@description('Log Analytics retention in days')
param logAnalyticsRetentionInDays int

var baseName = toLower('${projectName}-${environment}')
var acrName = toLower('${replace(projectName, '-', '')}${replace(environment, '-', '')}registry')
var aksName = '${baseName}-aks'
var workspaceName = '${baseName}-log'
var dnsPrefix = toLower('${projectName}-${environment}-dns')

resource acr 'Microsoft.ContainerRegistry/registries@2023-08-01-preview' = {
  name: acrName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    adminUserEnabled: false
    publicNetworkAccess: 'Enabled'
  }
  tags: {
    project: projectName
    environment: environment
  }
}

resource workspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = if (enableMonitoring) {
  name: workspaceName
  location: location
  properties: {
    retentionInDays: logAnalyticsRetentionInDays
    features: {
      legacy: 0
    }
  }
  tags: {
    project: projectName
    environment: environment
  }
}

resource aks 'Microsoft.ContainerService/managedClusters@2024-02-01' = {
  name: aksName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    dnsPrefix: dnsPrefix
    enableRBAC: true
    agentPoolProfiles: [
      {
        name: 'systempool'
        count: nodeCount
        vmSize: nodeVmSize
        osType: 'Linux'
        type: 'VirtualMachineScaleSets'
        mode: 'System'
        availabilityZones: [
          '1'
          '2'
          '3'
        ]
      }
    ]
    networkProfile: {
      networkPlugin: 'kubenet'
      loadBalancerSku: 'standard'
      outboundType: 'loadBalancer'
    }
    addonProfiles: enableMonitoring ? {
      omsagent: {
        enabled: true
        config: {
          logAnalyticsWorkspaceResourceID: workspace.id
        }
      }
    } : {}
  }
  tags: {
    project: projectName
    environment: environment
  }
}

resource acrPull 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acr.id, aks.id, 'AcrPull')
  scope: acr
  properties: {
    principalId: aks.properties.identityProfile.kubeletidentity.objectId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d') // AcrPull
  }
}

output aksName string = aks.name
output aksResourceId string = aks.id
output aksFqdn string = aks.properties.fqdn
output acrLoginServer string = acr.properties.loginServer
output acrResourceId string = acr.id
output kubeletIdentityObjectId string = aks.properties.identityProfile.kubeletidentity.objectId
output logAnalyticsWorkspaceId string = enableMonitoring ? workspace.id : ''
