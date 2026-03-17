import * as types from '../types.bicep'
param network types.networkParams

resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2025-05-01' = {
  name: network.networkSecurityGroupName
  location: resourceGroup().location
  properties: {
    securityRules: []
  }
}

resource routeTable 'Microsoft.Network/routeTables@2025-05-01' = {
  name: network.routeTablesName
  location: resourceGroup().location
  properties: {
    disableBgpRoutePropagation: false
    routes: []
  }
}

resource virtualNetwork_AzureFirewallSubnet 'Microsoft.Network/virtualNetworks/subnets@2025-05-01' = {
  // this is out-of-box
  parent: virtualNetwork
  name: 'AzureFirewallSubnet'
  properties: {
    addressPrefixes: [
      '10.0.1.0/26'
    ]
    delegations: []
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
  }
  dependsOn: [
    virtualNetwork_default
  ]
}

resource virtualNetwork_default 'Microsoft.Network/virtualNetworks/subnets@2025-05-01' = {
  // this is out-of-box
  parent: virtualNetwork
  name: 'default'
  properties: {
    addressPrefixes: [
      '10.0.0.0/24'
    ]
    delegations: []
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
  }
}

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2025-05-01' = {
  name: network.virtualNetworkName
  location: resourceGroup().location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    encryption: {
      enabled: false
      enforcement: 'AllowUnencrypted'
    }
    privateEndpointVNetPolicies: 'Disabled'
    enableDdosProtection: false
  }
}

resource virtualNetwork_snetKvWeb 'Microsoft.Network/virtualNetworks/subnets@2025-05-01' = {
  parent: virtualNetwork
  name: network.subnetName
  properties: {
    addressPrefixes: [
      '10.0.1.64/27'
    ]
    networkSecurityGroup: {
      id: networkSecurityGroup.id
    }
    routeTable: {
      id: routeTable.id
    }
    serviceEndpoints: [
      {
        service: 'Microsoft.KeyVault'
        locations: [
          '*'
        ]
      }
    ]
    delegations: [
      {
        name: 'Microsoft.Web/serverFarms'
        properties: {
          serviceName: 'Microsoft.Web/serverFarms'
        }
      }
    ]
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
  }
  dependsOn: [
    virtualNetwork_AzureFirewallSubnet
  ]
}
