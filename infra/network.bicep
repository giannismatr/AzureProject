param envName string
param location string
param allowedIpAddress string

// VNet: 10.0.0.0/16
// app subnet:              10.0.1.0/24  — Function App VNet integration
// private endpoint subnet: 10.0.2.0/24  — all PaaS private endpoints

resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: '${envName}-vnet'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: ['10.0.0.0/16']
    }
    subnets: [
      {
        name: 'app-subnet'
        properties: {
          addressPrefix: '10.0.1.0/24'
          networkSecurityGroup: { id: appNsg.id }
          delegations: [
            {
              name: 'functions-delegation'
              properties: {
                serviceName: 'Microsoft.Web/serverFarms'
              }
            }
          ]
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
      {
        name: 'pe-subnet'
        properties: {
          addressPrefix: '10.0.2.0/24'
          networkSecurityGroup: { id: peNsg.id }
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
    ]
  }
}

// Zero Trust: deny all inbound by default, allow only HTTPS from your IP
resource appNsg 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: '${envName}-app-nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'allow-https-from-my-ip'
        properties: {
          priority: 100
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: allowedIpAddress
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '443'
        }
      }
      {
        name: 'allow-vnet-inbound'
        properties: {
          priority: 200
          protocol: '*'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: 'VirtualNetwork'
          sourcePortRange: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          destinationPortRange: '*'
        }
      }
      {
        name: 'deny-all-inbound'
        properties: {
          priority: 4096
          protocol: '*'
          access: 'Deny'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
    ]
  }
}

// Private endpoint subnet: only allow traffic from within the VNet
resource peNsg 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: '${envName}-pe-nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'allow-vnet-only'
        properties: {
          priority: 100
          protocol: '*'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: 'VirtualNetwork'
          sourcePortRange: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          destinationPortRange: '*'
        }
      }
      {
        name: 'deny-all-inbound'
        properties: {
          priority: 4096
          protocol: '*'
          access: 'Deny'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
    ]
  }
}

output vnetId string = vnet.id
output vnetName string = vnet.name
output appSubnetId string = vnet.properties.subnets[0].id
output privateEndpointSubnetId string = vnet.properties.subnets[1].id
