import * as types from '../types.bicep'
param network types.networkParams
param configurationStoreResourceGroupName types.rgName
param configurationStore types.configurationStoreParam

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2025-05-01' existing = {
  name: network.virtualNetworkName
}

resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2025-05-01' existing = {
  name: network.networkSecurityGroup.name
}
resource routeTable 'Microsoft.Network/routeTables@2025-05-01' existing = {
  name: network.routeTablesName
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2025-05-01' = {
  parent: virtualNetwork
  name: configurationStore.privateEndpoint.subnetName
  properties: {
    addressPrefixes: configurationStore.privateEndpoint.addressPrefixes
    networkSecurityGroup: {
      id: networkSecurityGroup.id
    }
    routeTable: {
      id: routeTable.id
    }
    serviceEndpoints: [
      {
        service: 'Microsoft.Web'
        locations: [
          '*'
        ]
      }
    ]
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
  }
}

resource privatelink_azconfig_io 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: 'privatelink.azconfig.io'
  location: 'global'
  tags: {}
  properties: {}
}
resource privateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2025-05-01' = {
  parent: privateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink-azconfig-io'
        properties: {
          privateDnsZoneId: privatelink_azconfig_io.id
        }
      }
    ]
  }
}
resource virtualNetworkLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: privatelink_azconfig_io
  name: uniqueString(virtualNetwork.id)
  location: 'global'
  properties: {
    virtualNetwork: {
      id: virtualNetwork.id
    }
    registrationEnabled: false
  }
}

resource ApplicationSecurityGroup 'Microsoft.Network/applicationSecurityGroups@2025-05-01' = {
  name: configurationStore.privateEndpoint.applicationSecurityGroupName
  location: resourceGroup().location
}

resource configurationStoreResource 'Microsoft.AppConfiguration/configurationStores@2025-06-01-preview' existing = {
  name: configurationStore.name
  scope: resourceGroup(configurationStoreResourceGroupName)
}

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2025-05-01' = {
  name: configurationStore.privateEndpoint.name
  location: resourceGroup().location
  properties: {
    customNetworkInterfaceName: configurationStore.privateEndpoint.customNetworkInterfaceName
    subnet: {
      id: subnet.id
    }
    applicationSecurityGroups: [
      {
        id: ApplicationSecurityGroup.id
      }
    ]
    privateLinkServiceConnections: [
      {
        name: join(['pe', configurationStore.privateEndpoint.name, configurationStore.name], '-')
        properties: {
          privateLinkServiceId: configurationStoreResource.id
          groupIds: [
            'configurationStores'
          ]
        }
      }
    ]
  }
}
