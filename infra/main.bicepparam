using './main.bicep'

param network = {
  resourceGroupName: 'rg-lg-vnet-temp1'
  routeTablesName: 'rt-temp1'
  virtualNetworkName: 'vnet-temp1'
  networkSecurityGroupName: 'nsg-temp1'
  subnetName: 'snet-kv-web-temp1'
}
