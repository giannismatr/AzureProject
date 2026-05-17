targetScope = 'resourceGroup'

@description('Environment name used to prefix all resources')
param envName string = 'zt-demo'

@description('Azure region for all resources')
param location string = resourceGroup().location

@description('Your IP address for NSG allow rule (run: curl ifconfig.me)')
param allowedIpAddress string

module network 'network.bicep' = {
  name: 'network'
  params: {
    envName: envName
    location: location
    allowedIpAddress: allowedIpAddress
  }
}

module monitoring 'monitoring.bicep' = {
  name: 'monitoring'
  params: {
    envName: envName
    location: location
  }
}

module keyvault 'keyvault.bicep' = {
  name: 'keyvault'
  params: {
    envName: envName
    location: location
    privateEndpointSubnetId: network.outputs.privateEndpointSubnetId
    vnetId: network.outputs.vnetId
    logAnalyticsWorkspaceId: monitoring.outputs.workspaceId
  }
}

module storage 'storage.bicep' = {
  name: 'storage'
  params: {
    envName: envName
    location: location
    privateEndpointSubnetId: network.outputs.privateEndpointSubnetId
    vnetId: network.outputs.vnetId
    logAnalyticsWorkspaceId: monitoring.outputs.workspaceId
  }
}

module app 'app.bicep' = {
  name: 'app'
  params: {
    envName: envName
    location: location
    appSubnetId: network.outputs.appSubnetId
    keyVaultName: keyvault.outputs.keyVaultName
    storageAccountName: storage.outputs.storageAccountName
    logAnalyticsWorkspaceId: monitoring.outputs.workspaceId
  }
}

output functionAppUrl string = app.outputs.functionAppUrl
output keyVaultName string = keyvault.outputs.keyVaultName
output logAnalyticsWorkspaceId string = monitoring.outputs.workspaceId
