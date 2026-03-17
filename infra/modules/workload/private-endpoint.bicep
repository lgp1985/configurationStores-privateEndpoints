import * as types from '../types.bicep'
param network types.networkParams
param configurationStoreResourceGroupName types.rgName
param configurationStore types.configurationStoreParam

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2025-05-01' existing = {
  name: network.virtualNetworkName
}
resource virtualNetwork_AzureFirewallSubnet 'Microsoft.Network/virtualNetworks/subnets@2025-05-01' existing = {
  // this is out-of-box
  parent: virtualNetwork
  name: network.subnetName
}

// resource ApplicationSecurityGroup 'Microsoft.Network/applicationSecurityGroups@2025-05-01' existing = {
//   name: network.applicationSecurityGroup.name
// }

resource appConfig 'Microsoft.AppConfiguration/configurationStores@2025-06-01-preview' existing = {
  name: configurationStore.name
  scope: resourceGroup(configurationStoreResourceGroupName)
}

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2025-05-01' = {
  name: configurationStore.privateEndpoint.name
  location: resourceGroup().location
  properties: {
    customNetworkInterfaceName: configurationStore.privateEndpoint.customNetworkInterfaceName
    subnet: {
      id: virtualNetwork_AzureFirewallSubnet.id
    }
    // applicationSecurityGroups: [
    //   {
    //     id: ApplicationSecurityGroup.id
    //   }
    // ]
    privateLinkServiceConnections: [
      {
        name: join(['pe', configurationStore.privateEndpoint.name, configurationStore.name], '-')
        properties: {
          privateLinkServiceId: appConfig.id
          groupIds: [
            'configurationStores'
          ]
        }
      }
    ]
  }
}
