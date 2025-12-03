// main.bicep
targetScope = 'resourceGroup'

@description('Azure region for all resources')
param location string = 'westeurope'

@description('Short project name used for resource naming')
param projectName string = 'cart'

@description('Deployment environment tag/value (e.g. dev, test)')
param environment string = 'dev'

@description('AKS system node count')
param nodeCount int = 1

@description('AKS VM size for system node pool')
param nodeVmSize string = 'Standard_B4ms'

@description('Enable AKS monitoring via Log Analytics')
param enableMonitoring bool = true

@description('Log Analytics retention in days')
param logAnalyticsRetentionInDays int = 30

module aksStack 'modules/aks-infra.bicep' = {
  name: 'aksStack'
  params: {
    location: location
    projectName: projectName
    environment: environment
    nodeCount: nodeCount
    nodeVmSize: nodeVmSize
    enableMonitoring: enableMonitoring
    logAnalyticsRetentionInDays: logAnalyticsRetentionInDays
  }
}

output resourceGroupName string = resourceGroup().name
output resourceGroupId string = resourceGroup().id
output aksName string = aksStack.outputs.aksName
output aksResourceId string = aksStack.outputs.aksResourceId
output aksFqdn string = aksStack.outputs.aksFqdn
output acrLoginServer string = aksStack.outputs.acrLoginServer
output acrResourceId string = aksStack.outputs.acrResourceId
output kubeletIdentityObjectId string = aksStack.outputs.kubeletIdentityObjectId
output logAnalyticsWorkspaceId string = aksStack.outputs.logAnalyticsWorkspaceId
